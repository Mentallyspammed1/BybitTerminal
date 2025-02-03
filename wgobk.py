"""Bybit trading bot with order book analysis, indicators, and risk management."""

import json
import logging
import os
import time
import threading
import websocket
import pandas as pd
import numpy as np
import ccxt
from dotenv import load_dotenv
from collections import OrderedDict
from datetime import datetime
from colorama import Fore, Style, init

init(autoreset=True)

# Load environment variables
load_dotenv()

# --- Configuration ---
class Config:  # pylint: disable=too-few-public-methods,too-many-instance-attributes
    """Configuration settings for the bot."""
    def __init__(self, symbol):
        self.symbol = symbol
        self.order_book_depth = 50  # Match Bybit's supported depth
        self.trades_window = 20000
        self.trade_poll_interval = 3
        self.mfi_period = 14
        self.cci_period = 20
        self.williams_period = 14
        self.atr_period = 10
        self.stop_loss_multiplier_buy = 2.0
        self.take_profit_multiplier_buy = 1.0
        self.stop_loss_multiplier_sell = 1.5
        self.take_profit_multiplier_sell = 1.0
        self.round_decimals = 2
        self.imbalance_levels = 5
        self.imbalance_threshold_long = 1.6
        self.imbalance_threshold_short = 0.6
        self.cmi_period = 20
        self.ws_ping_interval = 20  # Seconds
        self.trade_size_usd = 5
        self.take_profit_percent = 0.01
        self.stop_loss_percent = 0.005


def initialize_config():
    """Handle user input and configuration setup."""
    symbol = input("Enter trading symbol (e.g., BTCUSDT): ").strip().upper()
    if not symbol:
        print("No symbol entered. Exiting.")
        sys.exit()
    return Config(symbol)


config = initialize_config()

# --- Bybit API Constants ---
BYBIT_WS_URL = "wss://stream.bybit.com/v5/public/spot"

# --- Data Structures ---
trades = pd.DataFrame(columns=["price", "size", "timestamp", "side"])
current_position = {"side": None, "entry_price": None, "size": 0}
BYBIT = None  # Initialize exchange globally

# --- Logging Setup ---
class ColorStreamHandler(logging.StreamHandler):
    """Custom handler for color-coded console output."""
    def emit(self, record):
        color_map = {
            logging.INFO: Fore.CYAN,
            logging.WARNING: Fore.YELLOW,
            logging.ERROR: Fore.RED,
            logging.CRITICAL: Fore.RED + Style.BRIGHT,
            logging.DEBUG: Fore.GREEN
        }
        color = color_map.get(record.levelno, Fore.WHITE)
        msg = f"{color}{self.format(record)}{Style.RESET_ALL}"
        print(msg)

def setup_logging():
    """Sets up the logger to output to a directory and file with color."""
    log_dir = "botlog"
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file_name = f"{config.symbol}_{timestamp}.log"
    log_file_path = os.path.join(log_dir, log_file_name)

    logging.basicConfig(
        level=logging.DEBUG, # Set default logging level to DEBUG for more output
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(log_file_path),
            ColorStreamHandler(), # Use ColorStreamHandler for console output
        ],
    )
    logging.info(f"Logging to file: {log_file_path}") # Info log for log file location

setup_logging()

# --- OrderBook Class (Fixed) ---
class OrderBook:
    """Maintains real-time order book state and generates signals."""
    def __init__(self):
        self.bids = OrderedDict()
        self.asks = OrderedDict()
        self.last_update_time = None

    def update(self, data):
        """Update order book from WebSocket data."""
        try:
            self.last_update_time = data.get("ts", time.time()) / 1000
            if "b" in data:
                self._update_side(self.bids, data["b"], is_bid=True)
            if "a" in data:
                self._update_side(self.asks, data["a"], is_bid=False)
        except KeyError as e:
            logging.error(f"Key error processing order book update: {e}")

    def _update_side(self, side, updates, is_bid):
        """Update bid or ask side of the order book."""
        try:
            # Process updates
            for price, size in updates:
                price = float(price)
                size = float(size)
                if size == 0:
                    side.pop(price, None)
                else:
                    side[price] = size

            # Sort and rebuild OrderedDict - Correctly sort bids descending and asks ascending
            items = sorted(side.items(), key=lambda x: (-x[0] if is_bid else x[0])) # Sort correctly
            side.clear()
            for price, size in items:
                side[price] = size
        except Exception as e:
            logging.error(f"Error updating order book side: {e}")

    def calculate_imbalance(self):
        """Calculates bid/ask imbalance with error handling."""
        try:
            bid_levels = list(self.bids.items())[:config.imbalance_levels]
            ask_levels = list(self.asks.items())[:config.imbalance_levels]

            bid_sum = sum(size for _, size in bid_levels)
            ask_sum = sum(size for _, size in ask_levels)

            if ask_sum <= 0:
                return 0 if bid_sum <= 0 else float('inf')
            return bid_sum / ask_sum
        except Exception as e:
            logging.error(f"Error calculating imbalance: {e}")
            return 0

    def get_midpoint(self):
        """Calculate current midpoint price."""
        try:
            best_bid = next(iter(self.bids)) if self.bids else None
            best_ask = next(iter(self.asks)) if self.asks else None
            if best_bid and best_ask:
                return (best_bid + best_ask) / 2
            return None
        except Exception as e:
            logging.error(f"Error getting midpoint: {e}")
            return None

    def generate_signal(self):
        """Generates trade signal based on current imbalance."""
        imbalance = self.calculate_imbalance()
        if imbalance > config.imbalance_threshold_long:
            return "LONG"
        elif imbalance < config.imbalance_threshold_short:
            return "SHORT"
        return None

order_book = OrderBook()

# --- Enhanced WebSocket Handlers ---
def on_message(ws, message):
    """Handle WebSocket messages and dispatch to appropriate processors."""
    try:
        msg = json.loads(message)
        if "topic" in msg:
            logging.debug(f"Received message on topic: {msg['topic']}") # Debug log for topic
            if "orderbook" in msg["topic"]:
                process_orderbook_message(msg)
            elif "publicTrade" in msg["topic"]:
                process_trade_message(msg)
        elif "event" in msg and msg["event"] == "pong":
            logging.debug("Pong received") # Debug log for pong
    except Exception as e:
        logging.error(f"Error processing message: {e}")

def process_orderbook_message(msg):
    """Process order book messages from WebSocket."""
    try:
        if msg["type"] == "snapshot":
            logging.debug("Processing orderbook snapshot") # Debug log for snapshot
            order_book.update(msg["data"])
        elif msg["type"] == "delta":
            logging.debug("Processing orderbook delta") # Debug log for delta
            order_book.update(msg["data"])

        # Log order book state
        midpoint = order_book.get_midpoint()
        imbalance = order_book.calculate_imbalance()
        if midpoint is not None: # Only log if midpoint is available
            logging.info(f"Order Book Midpoint: {midpoint:.4f}, Imbalance: {imbalance:.2f}")

        # Generate and act on signals
        signal = order_book.generate_signal()
        if signal:
            logging.info(f"Generated {signal} signal at {datetime.now()}")
            mid_price = order_book.get_midpoint()
            if mid_price:
                execute_trade_signal(signal, mid_price) # Execute trade based on signal
    except Exception as e:
        logging.error(f"Error processing order book message: {e}")

def process_trade_message(msg):
    """Process trade messages from WebSocket."""
    global trades
    try:
        new_trades = []
        for trade in msg["data"]:
            new_trades.append({
                "price": float(trade["p"]),
                "size": float(trade["v"]),
                "timestamp": float(trade["T"]) / 1000,
                "side": trade["S"].lower()
            })
        update_trades(new_trades)
    except Exception as e:
        logging.error(f"Error processing trade message: {e}")

def update_trades(new_trades):
    """Update trades dataframe with new trades."""
    global trades
    try:
        new_df = pd.DataFrame(new_trades)
        trades = pd.concat([trades, new_df]).drop_duplicates("timestamp").tail(config.trades_window)
        logging.debug(f"Updated trades. Current count: {len(trades)}")
    except Exception as e:
        logging.error(f"Error updating trades: {e}")

# --- Trading Execution and Position Management ---
def execute_trade_signal(signal, current_price):
    """Execute trade with position and risk management."""
    global current_position  # pylint: disable=global-statement
    global BYBIT # Ensure BYBIT is accessible

    if current_position["side"]:
        logging.warning("Existing position active. No new trades.")
        return

    amount = calculate_order_size(config.symbol, current_price)
    if not amount:
        return

    side = "buy" if signal == "LONG" else "sell"
    order = execute_market_order(config.symbol, side, amount)

    if order and order.get("info", {}).get("orderId"):
        current_position.update({
            "side": signal,
            "entry_price": order.get("price", current_price),
            "size": amount
        })
        log_color = Fore.GREEN if signal == "LONG" else Fore.MAGENTA
        logging.info("%s %s position opened @ %s", log_color, signal,
                     current_position["entry_price"])

def calculate_order_size(symbol, price):
    """Calculate order size in base currency."""
    global BYBIT # Ensure BYBIT is accessible
    try:
        markets = BYBIT.load_markets()
        market = markets[symbol]
        return round(config.trade_size_usd / price, market["precision"]["amount"])
    except KeyError:
        logging.error("Invalid symbol: %s", symbol)
        return None
    except ccxt.ExchangeError as e:
        logging.error("Exchange error: %s", e)
        return None

def execute_market_order(symbol, side, amount):
    """Execute market order with retry logic."""
    global BYBIT # Ensure BYBIT is accessible
    for _ in range(3):  # Retry up to 3 times
        try:
            return BYBIT.create_market_order(symbol, side, amount)
        except ccxt.NetworkError as e:
            logging.warning(f"Network error: {e}. Retrying...", exc_info=True) # Log full exception info
            time.sleep(2)
        except ccxt.ExchangeError as e:
            logging.error(f"Exchange error during order: {e}", exc_info=True) # Log full exception info
            return None # Stop retrying on ExchangeError (like insufficient balance)
    logging.error(f"Failed {side} order after 3 attempts")
    return None

# --- Indicator Calculations ---
def safe_division(numerator, denominator):
    """Safely divide, handling division by zero."""
    return numerator / denominator if denominator != 0 else 0

def calculate_cmi(trades_df):
    """Calculate Chande Momentum Oscillator (CMI)."""
    try:
        if len(trades_df) < config.cmi_period:
            return np.nan

        price_diff = trades_df["price"].diff()
        sum_up = price_diff.where(price_diff > 0, 0).rolling(config.cmi_period).sum()
        sum_down = (-price_diff).where(price_diff < 0, 0).rolling(config.cmi_period).sum()

        total = sum_up + sum_down
        return safe_division((sum_up - sum_down), total) * 100
    except Exception as e:
        logging.error(f"Error calculating CMI: {e}")
        return np.nan


# --- Exchange Initialization ---
def initialize_exchange():
    """Initialize and authenticate Bybit exchange."""
    global BYBIT # Use the global BYBIT variable
    load_dotenv()
    required_keys = ["BYBIT_API_KEY", "BYBIT_API_SECRET"]
    if not all(os.getenv(k) for k in required_keys):
        logging.error("Missing API credentials. Ensure BYBIT_API_KEY and BYBIT_API_SECRET are set in .env file.")
        sys.exit()

    try:
        BYBIT = ccxt.bybit({
            "apiKey": os.getenv("BYBIT_API_KEY"),
            "secret": os.getenv("BYBIT_API_SECRET"),
            "options": {"defaultType": "spot"}
        })
        logging.info(f"{Fore.GREEN}Bybit connection established{Style.RESET_ALL}") # Colored log
        return BYBIT
    except ccxt.AuthenticationError as e:
        logging.error(f"Authentication failed. Check API keys: {e}")
        sys.exit()
    except ccxt.NetworkError as e:
        logging.error(f"Network error during exchange initialization: {e}")
        sys.exit()
    except Exception as e: # Broader exception catch for init errors
        logging.error(f"Failed to initialize exchange: {e}")
        sys.exit()

# --- Main Execution Flow ---
def run_bot():
    """Main function to run the trading bot."""
    global BYBIT # Use the global BYBIT variable
    BYBIT = initialize_exchange() # Initialize exchange

    ws_app = websocket.WebSocketApp(
        BYBIT_WS_URL,
        on_open=lambda ws: on_open(ws, config.symbol), # Pass symbol to on_open
        on_message=on_message,
        on_error=lambda ws, e: logging.error(f"WebSocket Error: {e}", exc_info=True), # Log full WS errors
        on_close=on_close,
        on_ping=lambda ws, __: ws.send("ping") # Explicit ping response
    )

    # Start ping thread for connection maintenance
    threading.Thread(target=keep_alive, args=(ws_app,), daemon=True).start()

    # Optional: Start periodic health check thread (example)
    threading.Thread(target=periodic_health_check, daemon=True).start()

    ws_app.run_forever(ping_interval=config.ws_ping_interval) # Run WebSocket app

def on_open(ws, symbol):
    """WebSocket on_open handler to subscribe to orderbook and trades."""
    logging.info(f"WebSocket connection opened for symbol: {symbol}")
    ws.send(json.dumps({
        "op": "subscribe",
        "args": [
            f"orderbook.{config.order_book_depth}.{symbol}",
            f"publicTrade.{symbol}"
        ]
    }))

def on_close(ws, close_status_code, close_msg):
    """WebSocket on_close handler."""
    logging.info(f"WebSocket connection closed, status code: {close_status_code}, message: {close_msg}")

def keep_alive(ws_app):
    """Sends periodic pings to maintain WebSocket connection."""
    while True:
        time.sleep(config.ws_ping_interval)
        try:
            ws_app.send(json.dumps({"op": "ping"}))
            logging.debug("Ping sent to WebSocket server") # Debug log for ping
        except Exception as e:
            logging.error(f"Error sending ping, attempting to reconnect: {e}")
            break # Exit loop if ping fails, allowing reconnection attempt

def periodic_health_check():
    """Example of a periodic health check function."""
    while True:
        logging.info(f"Health Check - Trades Data Size: {trades.memory_usage().sum() / 1024:.2f} KB, Position Side: {current_position['side']}")
        logging.debug(f"Order Book Bid Depth: {len(order_book.bids)}, Ask Depth: {len(order_book.asks)}") # Debug log order book depth
        time.sleep(60) # Check every 60 seconds

if __name__ == "__main__":
    logging.info(f"{Fore.CYAN}Starting enhanced trading bot...{Style.RESET_ALL}") # Startup with color
    try:
        run_bot()
    except KeyboardInterrupt:
        logging.info(f"{Fore.YELLOW}Bot stopped by user{Style.RESET_ALL}") # Shutdown with color
    except Exception as e:
        logging.critical(f"{Fore.RED}Critical failure in run_bot: {e}{Style.RESET_ALL}", exc_info=True) # Critical error with color and full exception
