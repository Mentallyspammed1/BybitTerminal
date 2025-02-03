# -*- coding: utf-8 -*-
import json
import logging
import os
import sys
import time
import threading
import hashlib
import hmac
import requests
import websocket
import pandas as pd
import numpy as np
from datetime import datetime
from dotenv import load_dotenv
from collections import OrderedDict
from colorama import Fore, Style, init

init(autoreset=True)
load_dotenv()

class Config:
    def __init__(self, symbol):
        self.symbol = symbol
        self.order_book_depth = 50
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
        self.ws_ping_interval = 20
        self.trade_size_usd = 5
        self.take_profit_percent = 0.01
        self.stop_loss_percent = 0.005
        self.qty_step = 0.001
        self.min_qty = 0.001

BYBIT_REST_API_URL = "https://api.bybit.com"
BYBIT_WS_URL = "wss://stream.bybit.com/v5/public/linear"

def get_symbol_info(symbol):
    url = f"{BYBIT_REST_API_URL}/v5/market/instruments-info"
    params = {
        "category": "linear",
        "symbol": symbol
    }
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        if data.get('retCode') == 0:
            for item in data['result']['list']:
                if item['symbol'] == symbol:
                    return item
        logging.error(f"Failed to fetch symbol info: {data.get('retMsg', 'No message')}")
        return None
    except requests.exceptions.RequestException as e:
        logging.error(f"Error fetching symbol info: {e}")
        return None
    except json.JSONDecodeError as e:
        logging.error(f"Error decoding JSON response: {e}, Response: {response.text}")
        return None
    except Exception as e:
        logging.error(f"Unexpected error fetching symbol info: {e}", exc_info = True)
        return None

def initialize_config():
    symbol_input = input("Enter trading symbol (e.g., BTCUSDT): ").strip().upper()
    if not symbol_input:
        print("No symbol entered. Exiting.")
        sys.exit()
    symbol = symbol_input.replace("/", "")

    symbol_info = get_symbol_info(symbol)
    if not symbol_info:
        print("Failed to fetch symbol info. Exiting.")
        sys.exit()

    config = Config(symbol)
    lot_size_filter = symbol_info.get('lotSizeFilter', {})
    config.qty_step = float(lot_size_filter.get('qtyStep', '0.001'))
    config.min_qty = float(lot_size_filter.get('minOrderQty', '0.001'))
    return config

config = initialize_config()


trades = pd.DataFrame(columns=["price", "size", "timestamp", "side"])
current_position = {"side": None, "entry_price": None, "size": 0}
SESSION = requests.Session()
WS_APP = None

class ColorStreamHandler(logging.StreamHandler):
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
    log_dir = "botlog"
    full_log_path = os.path.join(log_dir, config.symbol.replace("/", "_"))

    if not os.path.exists(full_log_path):
        os.makedirs(full_log_path)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file_name = f"{config.symbol.replace('/', '_')}_{timestamp}.log"
    log_file_path = os.path.join(full_log_path, log_file_name)

    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(log_file_path),
            ColorStreamHandler(),
        ],
    )
    logging.info(f"Logging to file: {log_file_path}")

setup_logging()

class OrderBook:
    def __init__(self):
        self.bids = OrderedDict()
        self.asks = OrderedDict()
        self.last_update_time = None

    def update(self, data):
        try:
            self.last_update_time = data.get("ts", time.time()) / 1000
            if "b" in data:
                self._update_side(self.bids, data["b"], is_bid=True)
            if "a" in data:
                self._update_side(self.asks, data["a"], is_bid=False)
        except KeyError as e:
            logging.error(f"Key error processing order book update: {e}")

    def _update_side(self, side, updates, is_bid):
        try:
            for price, size in updates:
                price = float(price)
                size = float(size)
                if size == 0:
                    side.pop(price, None)
                else:
                    side[price] = size

            items = sorted(side.items(), key=lambda x: (-x[0] if is_bid else x[0]))
            side.clear()
            for price, size in items:
                side[price] = size
        except Exception as e:
            logging.error(f"Error updating order book side: {e}")

    def calculate_imbalance(self):
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
        imbalance = self.calculate_imbalance()
        if imbalance > config.imbalance_threshold_long:
            return "LONG"
        elif imbalance < config.imbalance_threshold_short:
            return "SHORT"
        return None

order_book = OrderBook()

def on_message(ws, message):
    try:
        msg = json.loads(message)
        if "topic" in msg:
            logging.debug(f"Received message on topic: {msg['topic']}")
            if "orderbook" in msg["topic"]:
                process_orderbook_message(msg)
            elif "publicTrade" in msg["topic"]:
                process_trade_message(msg)
        elif "event" in msg and msg["event"] == "pong":
            logging.debug("Pong received")
    except Exception as e:
        logging.error(f"Error processing message: {e}")

def process_orderbook_message(msg):
    try:
        if msg["type"] == "snapshot":
            logging.debug("Processing orderbook snapshot")
            order_book.update(msg["data"])
        elif msg["type"] == "delta":
            logging.debug("Processing orderbook delta")
            order_book.update(msg["data"])

        midpoint = order_book.get_midpoint()
        imbalance = order_book.calculate_imbalance()
        if midpoint is not None:
            logging.info(f"Order Book Midpoint: {midpoint:.4f}, Imbalance: {imbalance:.2f}")

        signal = order_book.generate_signal()
        if signal:
            logging.info(f"Generated {signal} signal at {datetime.now()}")
            mid_price = order_book.get_midpoint()
            if mid_price:
                execute_trade_signal(signal, mid_price)
    except Exception as e:
        logging.error(f"Error processing order book message: {e}")

def process_trade_message(msg):
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
    global trades
    try:
        new_df = pd.DataFrame(new_trades)
        trades = pd.concat([trades, new_df]).drop_duplicates("timestamp").tail(config.trades_window)
        logging.debug(f"Updated trades. Current count: {len(trades)}")
    except Exception as e:
        logging.error(f"Error updating trades: {e}")

def execute_trade_signal(signal, current_price):
    global current_position
    global SESSION

    if current_position["side"]:
        logging.warning("Existing position active. No new trades.")
        return

    amount = calculate_order_size(config.symbol, current_price)
    if not amount:
        return

    logging.debug(f"Calculated order amount: {amount}")
    side = "Buy" if signal == "LONG" else "Sell"
    order = execute_market_order(config.symbol, side, amount)

    if order and order.get("orderId"):
        current_position.update({
            "side": signal,
            "entry_price": float(order.get("price", current_price)),
            "size": amount
        })
        log_color = Fore.GREEN if signal == "LONG" else Fore.MAGENTA
        logging.info("%s %s position opened @ %s", log_color, signal, current_position["entry_price"])

def calculate_order_size(symbol, price):
    try:
        if price <= 0:
            logging.error("Invalid price for order size calculation")
            return None

        raw_qty = config.trade_size_usd / price
        rounded_qty = round(raw_qty / config.qty_step) * config.qty_step

        if rounded_qty < config.min_qty:
            logging.error(f"Quantity {rounded_qty} below minimum {config.min_qty}")
            return None

        precision = int(round(-np.log10(config.qty_step))) if config.qty_step < 1 else 3
        return round(rounded_qty, precision)

    except Exception as e:
        logging.error(f"Error calculating order size: {e}")
        return None

def generate_bybit_signature(api_secret, params):
    param_str = "&".join([f"{k}={v}" for k, v in sorted(params.items())])
    hash = hmac.new(api_secret.encode("utf-8"), param_str.encode("utf-8"), hashlib.sha256)
    return hash.hexdigest()

def execute_market_order(symbol, side, amount):
    global SESSION

    endpoint = "/v5/order/create"
    url = f"{BYBIT_REST_API_URL}{endpoint}"
    timestamp = str(int(time.time() * 1000))
    
    params = {
        "category": "linear",
        "symbol": symbol,
        "side": side,
        "orderType": "Market",
        "qty": str(amount),
        "timeInForce": "GTC",
        "api_key": os.getenv("BYBIT_API_KEY"),
        "timestamp": timestamp,
    }

    params['sign'] = generate_bybit_signature(os.getenv("BYBIT_API_SECRET"), params)
    
    headers = {"Content-Type": "application/x-www-form-urlencoded"}

    for _ in range(3):
        try:
            response = SESSION.post(url, data=params, headers=headers)
            response.raise_for_status()
            order_response = response.json()
            if order_response['retCode'] == 0:
                logging.info(f"Order Successful: {order_response}")
                return order_response['result']
            else:
                logging.error(f"Bybit order error: {order_response.get('retMsg', 'No message')}")
                return None
        except requests.exceptions.RequestException as e:
            logging.warning(f"Network error during order: {e}. Retrying...", exc_info=True)
            time.sleep(2)
        except json.JSONDecodeError as e:
            logging.error(f"JSON decode error from Bybit response: {e}, Response text: {response.text}", exc_info=True)
            return None
        except Exception as e:
            logging.error(f"Unexpected error during order: {e}", exc_info=True)
            return None
    logging.error(f"Failed {side} order after 3 attempts")
    return None

def safe_division(numerator, denominator):
    return numerator / denominator if denominator != 0 else 0

def calculate_cmi(trades_df):
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

def initialize_exchange():
    global SESSION
    global WS_APP
    load_dotenv()
    required_keys = ["BYBIT_API_KEY", "BYBIT_API_SECRET"]
    if not all(os.getenv(k) for k in required_keys):
        logging.error("Missing API credentials. Ensure BYBIT_API_KEY and BYBIT_API_SECRET are set in .env file.")
        sys.exit()

    try:
        SESSION = requests.Session()

        logging.info(f"{Fore.GREEN}Bybit REST API and WebSocket initialized (requests){Style.RESET_ALL}")

        return SESSION, WS_APP
    except Exception as e:
        logging.error(f"Failed to initialize requests Session or WebSocket: {e}")
        sys.exit()

def run_bot():
    global SESSION, WS_APP
    SESSION, WS_APP = initialize_exchange()

    WS_APP = websocket.WebSocketApp(
        BYBIT_WS_URL,
        on_open=lambda ws: on_open(ws, config.symbol),
        on_message=on_message,
        on_error=lambda ws, e: logging.error(f"WebSocket Error: {e}", exc_info=True),
        on_close=on_close,
        on_ping=lambda ws, __: ws.send("ping")
    )

    threading.Thread(target=keep_alive, args=(WS_APP,), daemon=True).start()
    threading.Thread(target=periodic_health_check, daemon=True).start()

    WS_APP.run_forever(ping_interval=config.ws_ping_interval)

def on_open(ws, symbol):
    logging.info(f"WebSocket connection opened for symbol: {symbol}")
    ws.send(json.dumps({
        "op": "subscribe",
        "args": [
            f"orderbook.{config.order_book_depth}.{symbol}",
            f"publicTrade.{symbol}"
        ]
    }))

def on_close(ws, close_status_code, close_msg):
    logging.info(f"WebSocket connection closed, status code: {close_status_code}, message: {close_msg}")

def keep_alive(ws_app):
    while True:
        time.sleep(config.ws_ping_interval)
        try:
            ws_app.send(json.dumps({"op": "ping"}))
            logging.debug("Ping sent to WebSocket server")
        except Exception as e:
            logging.error(f"Error sending ping, attempting to reconnect: {e}")
            break

def periodic_health_check():
    while True:
        logging.info(f"Health Check - Trades Data Size: {trades.memory_usage().sum() / 1024:.2f} KB, Position Side: {current_position['side']}")
        logging.debug(f"Order Book Bid Depth: {len(order_book.bids)}, Ask Depth: {len(order_book.asks)}")
        time.sleep(60)

if __name__ == "__main__":
    logging.info(f"{Fore.CYAN}Starting requests-based Bybit USDT Futures trading bot...{Style.RESET_ALL}")
    try:
        run_bot()
    except KeyboardInterrupt:
        logging.info(f"{Fore.YELLOW}Bot stopped by user{Style.RESET_ALL}")
    except Exception as e:
        logging.critical(f"{Fore.RED}Critical failure in run_bot: {e}{Style.RESET_ALL}", exc_info=True)
