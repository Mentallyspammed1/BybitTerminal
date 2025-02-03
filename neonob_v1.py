"""Simplified Bybit Futures Trading Bot - No Symbol Validation - Colorized"""

import json
import logging
import os
import sys
import time
import threading
import websocket
import pandas as pd
import ccxt
from dotenv import load_dotenv
from collections import OrderedDict
from datetime import datetime
from colorama import Fore, Style, init

init(autoreset=True)

# Global Constants
CURRENT_TIME = "2025-02-03 19:54:52"  # Updated UTC time
CURRENT_USER = "Mentallyspammed1"     # Updated username
LOG_DIR = "logs"
BYBIT_WS_URL = "wss://stream.bybit.com/v5/public/linear"

class Config:
    """Trading configuration parameters."""
    def __init__(self, symbol):
        # Trading parameters
        self.symbol = symbol
        self.order_book_depth = 50
        self.trades_window = 20000
        self.imbalance_levels = 5
        self.imbalance_threshold_long = 1.6
        self.imbalance_threshold_short = 0.6
        self.trade_size_usd = 5
        self.take_profit_percent = 0.01
        self.stop_loss_percent = 0.005
        self.ws_ping_interval = 20
        
        # System parameters
        self.user = CURRENT_USER
        self.start_time = CURRENT_TIME

def format_symbol(symbol: str) -> str:
    """Format symbol for Bybit linear perpetual markets."""
    return f"{symbol.upper().replace('/', '').replace('USDT', '')}USDT"

class ColorFormatter(logging.Formatter):
    """Custom formatter for colored console output."""
    COLORS = {
        logging.DEBUG: Fore.CYAN,
        logging.INFO: Fore.GREEN,
        logging.WARNING: Fore.YELLOW,
        logging.ERROR: Fore.RED,
        logging.CRITICAL: Fore.RED + Style.BRIGHT
    }

    def format(self, record):
        color = self.COLORS.get(record.levelno, Fore.WHITE)
        return f"{color}{super().format(record)}{Style.RESET_ALL}"

def setup_logging(symbol):
    """Configure logging with both file and colored console output."""
    os.makedirs(LOG_DIR, exist_ok=True)
    file_path = os.path.join(LOG_DIR, f"{symbol}_{CURRENT_TIME.replace(' ', '_').replace(':', '-')}.log")
    
    handlers = [
        logging.FileHandler(file_path, mode='w'),
        logging.StreamHandler()
    ]
    handlers[1].setFormatter(ColorFormatter())
    
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=handlers
    )

class OrderBook:
    """Maintains order book state and calculates trading signals."""
    def __init__(self):
        self.bids = OrderedDict()
        self.asks = OrderedDict()
        self.last_update = None

    def update(self, data):
        """Update order book with new data."""
        try:
            if data.get("type") == "snapshot":
                self.bids.clear()
                self.asks.clear()

            for bid in data.get("b", []):
                price, size = float(bid[0]), float(bid[1])
                if size > 0:
                    self.bids[price] = size
                else:
                    self.bids.pop(price, None)

            for ask in data.get("a", []):
                price, size = float(ask[0]), float(ask[1])
                if size > 0:
                    self.asks[price] = size
                else:
                    self.asks.pop(price, None)

            self.last_update = time.time()
        except Exception as e:
            logging.error(f"Order book update error: {e}")

    def get_imbalance(self):
        """Calculate order book imbalance ratio."""
        try:
            bid_levels = list(self.bids.items())[:config.imbalance_levels]
            ask_levels = list(self.asks.items())[:config.imbalance_levels]
            
            bid_sum = sum(size for _, size in bid_levels)
            ask_sum = sum(size for _, size in ask_levels)
            
            return bid_sum / ask_sum if ask_sum else float('inf') if bid_sum else 0
        except Exception as e:
            logging.error(f"Imbalance calculation error: {e}")
            return 1.0

    def get_mid_price(self):
        """Calculate mid price from best bid and ask."""
        try:
            if self.bids and self.asks:
                return (max(self.bids.keys()) + min(self.asks.keys())) / 2
            return None
        except Exception as e:
            logging.error(f"Mid price calculation error: {e}")
            return None

class WebSocketManager(threading.Thread):
    """Manages WebSocket connection and message processing."""
    def __init__(self, order_book, symbol):
        super().__init__(daemon=True)
        self.ws = None
        self.running = True
        self.order_book = order_book
        self.symbol = symbol
        self.connect()

    def connect(self):
        """Establish WebSocket connection."""
        self.ws = websocket.WebSocketApp(
            BYBIT_WS_URL,
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close
        )

    def run(self):
        """Main WebSocket loop with automatic reconnection."""
        while self.running:
            try:
                self.ws.run_forever(ping_interval=config.ws_ping_interval, ping_timeout=10)
            except Exception as e:
                logging.error(f"WebSocket error: {e}")
            if self.running:
                logging.info("Attempting to reconnect...")
                time.sleep(5)
                self.connect()

    def on_open(self, ws):
        """Handle WebSocket connection opening."""
        logging.info("WebSocket connected")
        self.subscribe_to_feeds()

    def subscribe_to_feeds(self):
        """Subscribe to market data feeds."""
        try:
            subscribe_msg = {
                "op": "subscribe",
                "args": [
                    f"orderbook.{config.order_book_depth}.{self.symbol}",
                    f"publicTrade.{self.symbol}"
                ]
            }
            self.ws.send(json.dumps(subscribe_msg))
            logging.info(f"Subscribed to market data feeds for {self.symbol}")
        except Exception as e:
            logging.error(f"Subscription error: {e}")

    def on_message(self, ws, message):
        """Process incoming WebSocket messages."""
        try:
            data = json.loads(message)
            if "topic" in data:
                if "orderbook" in data["topic"]:
                    self.order_book.update(data["data"])
                    self.check_trading_signals()
                elif "trade" in data["topic"]:
                    self.process_trade(data["data"])
        except Exception as e:
            logging.error(f"Message processing error: {e}")

    def check_trading_signals(self):
        """Check for trading opportunities."""
        try:
            imbalance = self.order_book.get_imbalance()
            mid_price = self.order_book.get_mid_price()
            
            if not mid_price:
                return
                
            logging.info(f"Imbalance: {imbalance:.2f}, Mid Price: {mid_price:.2f}")
            
            if imbalance > config.imbalance_threshold_long:
                self.execute_trade("buy", mid_price)
            elif imbalance < config.imbalance_threshold_short:
                self.execute_trade("sell", mid_price)
        except Exception as e:
            logging.error(f"Signal check error: {e}")

    def execute_trade(self, side, price):
        """Execute trade based on signal."""
        if current_position["side"]:
            logging.info("Position already open, skipping trade")
            return
            
        try:
            amount = config.trade_size_usd / price
            order = BYBIT.create_market_order(
                config.symbol,
                side,
                amount,
                params={"reduceOnly": False}
            )
            
            if order["id"]:
                logging.info(f"Trade executed: {side.upper()} {amount:.8f} @ {price:.2f}")
                current_position.update({
                    "side": side,
                    "entry_price": price,
                    "size": amount
                })
        except Exception as e:
            logging.error(f"Trade execution error: {e}")

    def process_trade(self, trade_data):
        """Process and store trade data."""
        try:
            new_trades = [{
                "price": float(trade["p"]),
                "size": float(trade["v"]),
                "timestamp": int(trade["T"]),
                "side": trade["S"].lower()
            } for trade in trade_data]
            
            global trades
            trades = pd.concat([trades, pd.DataFrame(new_trades)], ignore_index=True)
            if len(trades) > config.trades_window:
                trades = trades.iloc[-config.trades_window:].copy()
        except Exception as e:
            logging.error(f"Trade processing error: {e}")

    def on_error(self, ws, error):
        logging.error(f"WebSocket error: {error}")

    def on_close(self, ws, close_code, close_msg):
        logging.info(f"WebSocket closed (code: {close_code}, message: {close_msg or 'None'})")

def initialize_exchange():
    """Initialize exchange connection with API credentials."""
    global BYBIT
    load_dotenv()
    
    required_keys = ["BYBIT_API_KEY", "BYBIT_API_SECRET"]
    if not all(os.getenv(key) for key in required_keys):
        logging.critical("Missing API credentials in .env file")
        sys.exit(1)

    try:
        BYBIT = ccxt.bybit({
            'apiKey': os.environ['BYBIT_API_KEY'],
            'secret': os.environ['BYBIT_API_SECRET'],
            'options': {
                'defaultType': 'linear',
                'adjustForTimeDifference': True
            }
        })
        BYBIT.load_markets()
        logging.info("Successfully connected to Bybit")
    except Exception as e:
        logging.critical(f"Exchange initialization failed: {e}")
        sys.exit(1)

def main():
    """Main execution flow."""
    try:
        # Get trading symbol from user
        symbol_input = input("Enter trading symbol (e.g., BTC for BTCUSDT): ").strip()
        symbol = format_symbol(symbol_input)
        
        # Initialize configuration
        global config
        config = Config(symbol)
        
        # Setup logging
        setup_logging(symbol)
        
        # Initialize exchange
        initialize_exchange()
        
        # Logging start information
        logging.info(f"Bot started - User: {CURRENT_USER}, Time: {CURRENT_TIME}, Symbol: {config.symbol}, Size: {config.trade_size_usd} USDT")
        
        # Initialize order book and WebSocket manager
        order_book = OrderBook()
        ws_manager = WebSocketManager(order_book, config.symbol)
        ws_manager.start()
        
        # Keep main thread alive
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        logging.info("Shutting down gracefully...")
    except Exception as e:
        logging.critical(f"Fatal error: {e}")
    finally:
        logging.info("Bot stopped")

if __name__ == "__main__":
    main()
