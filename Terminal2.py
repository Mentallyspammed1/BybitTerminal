#!/usr/bin/env python3
"""Bybit Futures Terminal - v0.8 - WorldGuides Edit - RSI Fixed

Enhanced with pandas for data display. CCXT for market data & account info.
Requests for order placement. Includes RSI, ATR, and Fibonacci Pivot Points indicators from indicators/.
Data type conversion fix implemented in RSI function.
Output messages cleaned and color scheme updated to "neon".
"""

import os
import time
import hashlib
import hmac
import urllib.parse
import json

from dotenv import load_dotenv
import requests
import pandas as pd
import ccxt
from colorama import init, Fore, Style

from indicators import rsi, ATR, FibonacciPivotPoints  # Import FibonacciPivotPoints

# Initialize Colorama
init(autoreset=True)

# Load environment variables
load_dotenv()
BYBIT_API_KEY = os.environ.get("BYBIT_API_KEY")
BYBIT_API_SECRET = os.environ.get("BYBIT_API_SECRET")

if not BYBIT_API_KEY or not BYBIT_API_SECRET:
    print(
        Fore.RED
        + Style.BRIGHT
        + "Error: API keys not found in .env file. Cannot initialize."
    )
    BYBIT_API_KEY = None
    BYBIT_API_SECRET = None
else:
    print(Fore.GREEN + Style.BRIGHT + "API keys loaded from .env")

# Initialize CCXT Bybit exchange object
EXCHANGE = None
if BYBIT_API_KEY and BYBIT_API_SECRET:
    try:
        EXCHANGE = ccxt.bybit(
            {
                "apiKey": BYBIT_API_KEY,
                "secret": BYBIT_API_SECRET,
                "options": {"defaultType": "swap"},
            }
        )
        print(Fore.CYAN + Style.BRIGHT + "CCXT Bybit Futures client initialized.")
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error initializing CCXT: {e}")
        EXCHANGE = None


# --- Requests-based Order Functions ---
def generate_signature(api_secret, params):
    """Generates API signature for Bybit requests."""
    query_string = urllib.parse.urlencode(sorted(params.items()))
    signature = hmac.new(
        api_secret.encode("utf-8"), query_string.encode("utf-8"), hashlib.sha256
    ).hexdigest()
    return signature


def place_bybit_order_requests(symbol, side, order_type, qty, price=None):
    """Places a Bybit order using direct requests."""
    if not BYBIT_API_KEY or not BYBIT_API_SECRET:
        print(Fore.RED + Style.BRIGHT + "API keys not loaded. Order placement failed.")
        return None

    api_endpoint = "https://api.bybit.com/v5/order/create"
    timestamp = str(int(time.time() * 1000))
    params = {
        "category": "linear",
        "symbol": symbol,
        "side": side.capitalize(),
        "orderType": order_type.capitalize(),
        "qty": str(qty),
        "timeInForce": "GTC",
        "timestamp": timestamp,
        "recvWindow": "5000",
        "api_key": BYBIT_API_KEY,
    }
    if order_type.lower() == "limit" and price is not None:
        params["price"] = str(price)

    signature = generate_signature(BYBIT_API_SECRET, params)
    headers = {"Content-Type": "application/json"}
    params["sign"] = signature

    try:
        response = requests.post(api_endpoint, headers=headers, json=params)
        response.raise_for_status()
        order_data = response.json()

        if order_data and order_data["retCode"] == 0:
            print(
                Fore.GREEN
                + Style.BRIGHT
                + f"{order_type.capitalize()} order placed successfully!"
            )
            order_info = order_data.get("result", {}).get("order", {})
            if order_info:
                print(
                    Fore.WHITE
                    + f"  Order ID: {Fore.CYAN}{order_info.get('orderId', 'N/A')}"
                )
                print(
                    Fore.WHITE
                    + f"  Symbol: {Fore.GREEN}{order_info.get('symbol', 'N/A')}"
                )
                print(
                    Fore.WHITE
                    + f"  Side: {Fore.GREEN if order_info.get('side', '').lower() == 'buy' else Fore.RED}{order_info.get('side', 'N/A').upper()}"
                )
                print(
                    Fore.WHITE
                    + f"  Quantity: {Fore.GREEN}{order_info.get('qty', 'N/A')}"
                )
                if "price" in order_info:
                    print(
                        Fore.WHITE
                        + f"  Price: {Fore.GREEN}{order_info.get('price', 'N/A')}"
                    )
                return order_info
            else:
                print(
                    Fore.YELLOW
                    + Style.BRIGHT
                    + "Warning: Order placed, but details missing from API response."
                )
                return None
        else:
            print(
                Fore.RED
                + Style.BRIGHT
                + f"Bybit API Error: {order_data.get('retMsg', 'Unknown error')}"
            )
            return None

    except requests.exceptions.RequestException as e:
        print(Fore.RED + Style.BRIGHT + f"Request Exception: {e}")
        return None
    except json.JSONDecodeError:
        print(
            Fore.RED + Style.BRIGHT + "Failed to decode JSON response from Bybit API."
        )
        return None


def place_market_order_requests():
    """Places a market order - Requests."""
    symbol = input(Fore.YELLOW + "Enter symbol (e.g., BTCUSDT): ").upper()
    side = input(Fore.YELLOW + "Buy/Sell: ").lower()
    amount = float(input(Fore.YELLOW + "Enter quantity: "))

    order_details = place_bybit_order_requests(symbol, side, "market", amount)
    if order_details:
        os.system("clear")
        print(
            Fore.CYAN
            + Style.BRIGHT
            + "╔═══════════"
            + Fore.GREEN
            + "MARKET ORDER EXECUTED"
            + Fore.CYAN
            + "════════════╗"
        )
        print(Fore.WHITE + f"\nSymbol: {Fore.GREEN}{symbol}")
        print(
            Fore.WHITE
            + f"Side: {Fore.GREEN if side == 'buy' else Fore.RED}{side.upper()}"
        )
        print(Fore.WHITE + f"Amount: {Fore.GREEN}{amount}")
        if order_details.get("orderId"):
            print(Fore.WHITE + f"Order ID: {Fore.CYAN}{order_details['orderId']}")
    else:
        print(Fore.RED + Style.BRIGHT + "Market order placement failed.")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def place_limit_order_requests():
    """Places a limit order - Requests."""
    symbol = input(Fore.YELLOW + "Enter symbol (e.g., BTCUSDT): ").upper()
    side = input(Fore.YELLOW + "Buy/Sell: ").lower()
    amount = float(input(Fore.YELLOW + "Enter quantity: "))
    price = float(input(Fore.YELLOW + "Enter price: "))

    order_details = place_bybit_order_requests(symbol, side, "limit", amount, price)
    if order_details:
        os.system("clear")
        print(
            Fore.CYAN
            + Style.BRIGHT
            + "╔═══════════"
            + Fore.GREEN
            + "LIMIT ORDER PLACED"
            + Fore.CYAN
            + "═══════════╗"
        )
        print(Fore.WHITE + f"\nSymbol: {Fore.GREEN}{symbol}")
        print(
            Fore.WHITE
            + f"Side: {Fore.GREEN if side == 'buy' else Fore.RED}{side.upper()}"
        )
        print(Fore.WHITE + f"Amount: {Fore.GREEN}{amount}")
        print(Fore.WHITE + f"Price: {Fore.GREEN}{price}")
        if order_details.get("orderId"):
            print(Fore.WHITE + f"Order ID: {Fore.CYAN}{order_details['orderId']}")
    else:
        print(Fore.RED + Style.BRIGHT + "Limit order placement failed.")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def display_main_menu():
    """Displays the main menu."""
    os.system("clear")
    print(Fore.CYAN + Style.BRIGHT + "╔══════════════════════════════════╗")
    print(
        Fore.CYAN
        + Style.BRIGHT
        + "║   "
        + Fore.MAGENTA
        + "Bybit Futures Terminal v0.8"
        + Fore.CYAN
        + "    ║"
    )
    print(
        Fore.CYAN
        + Style.BRIGHT
        + "║   "
        + Fore.GREEN
        + "    WorldGuides Edit - Neon Edition   "
        + Fore.CYAN
        + "   ║"
    )  # Changed line
    print(Fore.CYAN + Style.BRIGHT + "║       Powered by Pyrrmethus       ║")
    print(Fore.CYAN + Style.BRIGHT + "╚══════════════════════════════════╝")
    print(Fore.YELLOW + Style.BRIGHT + "\nChoose a category:")
    print(Fore.MAGENTA + "1. Account Operations")
    print(Fore.MAGENTA + "2. Market Data")
    print(Fore.MAGENTA + "3. Trading Actions")
    print(Fore.MAGENTA + "4. Display API Keys (Debug)")
    print(Fore.MAGENTA + "5. Exit")
    return input(Fore.YELLOW + Style.BRIGHT + "Enter your choice (1-5): ")


def display_trading_menu():
    """Displays the Trading Actions submenu."""
    os.system("clear")
    print(Fore.CYAN + Style.BRIGHT + "╔══════════════════════════════════╗")
    print(
        Fore.CYAN
        + Style.BRIGHT
        + "║    "
        + Fore.GREEN
        + "Bybit Futures Trading Actions"
        + Fore.CYAN
        + "   ║"
    )
    print(Fore.CYAN + Style.BRIGHT + "║      (Using Direct Requests)      ║")
    print(Fore.CYAN + Style.BRIGHT + "╚══════════════════════════════════╝")
    print(Fore.YELLOW + Style.BRIGHT + "\nChoose an action:")
    print(Fore.MAGENTA + "1. Place Market Order")
    print(Fore.MAGENTA + "2. Place Limit Order")
    print(Fore.MAGENTA + "3. Cancel Futures Order (CCXT) - WIP")
    print(Fore.MAGENTA + "4. View Open Futures Orders (CCXT) - WIP")
    print(Fore.MAGENTA + "5. View Open Futures Positions (CCXT) - WIP")
    print(Fore.MAGENTA + "6. Place Trailing Stop (Simulated) - WIP")
    print(Fore.MAGENTA + "7. Back to Main Menu")
    return input(Fore.YELLOW + Style.BRIGHT + "Enter your choice (1-7): ")


def view_account_menu():
    """Displays the Account Operations submenu."""
    os.system("clear")
    print(Fore.CYAN + Style.BRIGHT + "╔══════════════════════════════════╗")
    print(
        Fore.CYAN
        + Style.BRIGHT
        + "║   "
        + Fore.GREEN
        + "Bybit Futures Account Operations"
        + Fore.CYAN
        + "  ║"
    )
    print(Fore.CYAN + Style.BRIGHT + "║     (Using CCXT & Pandas)        ║")
    print(Fore.CYAN + Style.BRIGHT + "╚══════════════════════════════════╝")
    print(Fore.YELLOW + Style.BRIGHT + "\nChoose an action:")
    print(Fore.MAGENTA + "1. View Account Balance")
    print(Fore.MAGENTA + "2. View Order History")
    print(Fore.MAGENTA + "3. Deposit Funds (Simulated)")
    print(Fore.MAGENTA + "4. Withdraw Funds (Simulated)")
    print(Fore.MAGENTA + "5. Back to Main Menu")
    return input(Fore.YELLOW + Style.BRIGHT + "\nEnter your choice (1-5): ")


def display_market_menu():
    """Displays the Market Data submenu."""
    os.system("clear")
    print(Fore.CYAN + Style.BRIGHT + "╔══════════════════════════════════╗")
    print(
        Fore.CYAN
        + Style.BRIGHT
        + "║     "
        + Fore.GREEN
        + "Bybit Futures Market Data"
        + Fore.CYAN
        + "     ║"
    )
    print(Fore.CYAN + Style.BRIGHT + "║         (Using CCXT)             ║")
    print(Fore.CYAN + Style.BRIGHT + "╚══════════════════════════════════╝")
    print(Fore.YELLOW + Style.BRIGHT + "\nChoose data to retrieve:")
    print(Fore.MAGENTA + "1. Fetch Symbol Price")
    print(Fore.MAGENTA + "2. Get Order Book")
    print(Fore.MAGENTA + "3. List Available Symbols")
    print(Fore.MAGENTA + "4. Display RSI (Relative Strength Index)")
    print(Fore.MAGENTA + "5. Display ATR (Average True Range)")
    print(Fore.MAGENTA + "6. Display Fibonacci Pivot Points")  # New option
    print(Fore.MAGENTA + "7. Back to Main Menu")
    return input(Fore.YELLOW + Style.BRIGHT + "Enter your choice (1-7): ")


def view_account_balance():
    """Fetches and displays Futures account balance - CCXT & Pandas."""
    if not EXCHANGE:
        print(Fore.RED + Style.BRIGHT + "CCXT Bybit client not initialized.")
        return

    try:
        balance = EXCHANGE.fetch_balance()
        if balance and "USDT" in balance and isinstance(balance["USDT"], dict):
            os.system("clear")
            print(
                Fore.CYAN
                + Style.BRIGHT
                + "╔═══════════"
                + Fore.GREEN
                + "ACCOUNT BALANCE"
                + Fore.CYAN
                + "════════════╗"
            )
            usdt_balance = balance.get("USDT", {})
            total_balance = usdt_balance.get("total", float("nan"))
            free_balance = usdt_balance.get("free", float("nan"))

            balance_df = pd.DataFrame(
                [{"currency": "USDT", "total": total_balance, "free": free_balance}]
            )

            if (
                not balance_df.empty
                and not balance_df[["total", "free"]].isnull().all().all()
            ):
                print(
                    Fore.WHITE + Style.BRIGHT + "\nBalances (USDT Perpetual Futures):"
                )
                print(
                    Fore.GREEN
                    + balance_df[["currency", "total", "free"]].to_string(
                        index=False,
                        formatters={"total": "{:.4f}".format, "free": "{:.4f}".format},
                    )
                )
            else:
                print(Fore.YELLOW + "  USDT balance information unavailable.")
            print(
                Fore.CYAN + Style.BRIGHT + "\n---------------------------------------"
            )
        else:
            print(Fore.RED + "Could not fetch account balance or invalid data.")

    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error fetching balance: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def view_order_history():
    """Fetches and displays Futures order history - CCXT & Pandas."""
    if not EXCHANGE:
        print(Fore.RED + "CCXT Bybit client not initialized.")
        return

    try:
        symbol = input(Fore.YELLOW + "Enter Futures symbol (e.g., BTC/USDT): ").upper()
        if "/" not in symbol:
            symbol += "/USDT"

        orders = EXCHANGE.fetch_closed_orders(
            symbol=symbol
        ) + EXCHANGE.fetch_canceled_orders(symbol=symbol)

        if orders:
            os.system("clear")
            print(
                Fore.CYAN
                + Style.BRIGHT
                + f"╔══════════"
                + Fore.GREEN
                + "ORDER HISTORY FOR {symbol:<8}".format(symbol=symbol)
                + Fore.CYAN
                + "══════════╗"
            )

            order_df = pd.DataFrame(orders)
            if not order_df.empty:
                order_df["datetime"] = pd.to_datetime(order_df["datetime"])
                order_df = order_df[
                    [
                        "datetime",
                        "id",
                        "side",
                        "amount",
                        "price",
                        "status",
                        "type",
                        "symbol",
                    ]
                ]
                print(Fore.WHITE + Style.BRIGHT + "\nOrder History:")
                print(Fore.CYAN + "-" * 120)
                print(
                    Fore.WHITE
                    + order_df.to_string(
                        index=False,
                        formatters={
                            "price": "{:.2f}".format,
                            "amount": "{:.4f}".format,
                        },
                    )
                )
                print(Fore.CYAN + "-" * 120)
            else:
                print(Fore.YELLOW + f"No orders found for {symbol}")
        else:
            print(Fore.YELLOW + f"No orders found for {symbol}")

    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error fetching order history: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def fetch_symbol_price():
    """Fetches and displays the current price of a Futures symbol."""
    if not EXCHANGE:
        print(Fore.RED + Style.BRIGHT + "CCXT Bybit client not initialized.")
        return

    symbol = input(Fore.YELLOW + "Enter Futures symbol (e.g., BTCUSDT): ").upper()
    try:
        ticker = EXCHANGE.fetch_ticker(symbol)
        if ticker and "last" in ticker:
            os.system("clear")
            print(
                Fore.CYAN
                + Style.BRIGHT
                + "╔════════════"
                + Fore.GREEN
                + "SYMBOL PRICE"
                + Fore.CYAN
                + "═════════════╗"
            )
            print(
                Fore.WHITE
                + Style.BRIGHT
                + f"\nCurrent price of {Fore.GREEN}{symbol}{Fore.WHITE}: {Fore.GREEN}{ticker['last']:.2f}"
            )
        else:
            print(Fore.RED + Style.BRIGHT + f"Could not fetch price for {symbol}")
    except ccxt.ExchangeError as e:
        print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error: {e}")
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error fetching price: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def get_order_book():
    """Fetches and displays the order book for a Futures symbol."""
    if not EXCHANGE:
        print(Fore.RED + Style.BRIGHT + "CCXT Bybit client not initialized.")
        return

    symbol = input(Fore.YELLOW + "Enter Futures symbol (e.g., BTCUSDT): ").upper()
    try:
        orderbook = EXCHANGE.fetch_order_book(symbol)
        if orderbook and "bids" in orderbook and "asks" in orderbook:
            os.system("clear")
            print(
                Fore.CYAN
                + Style.BRIGHT
                + f"╔═══════════"
                + Fore.GREEN
                + "ORDER BOOK FOR {symbol:<8}".format(symbol=symbol)
                + Fore.CYAN
                + "══════════╗"
            )
            bid_df = pd.DataFrame(
                orderbook["bids"][:10], columns=["Price", "Amount"]
            )
            ask_df = pd.DataFrame(
                orderbook["asks"][:10], columns=["Price", "Amount"]
            )

            if not bid_df.empty and not ask_df.empty:
                print(
                    Fore.WHITE
                    + Style.BRIGHT
                    + "\nTop 10 Bids:\n"
                    + Fore.GREEN
                    + bid_df.to_string(
                        index=False, formatters={"Price": "{:.2f}".format}
                    )
                )
                print(
                    Fore.WHITE
                    + Style.BRIGHT
                    + "\n\nTop 10 Asks:\n"
                    + Fore.RED
                    + ask_df.to_string(
                        index=False, formatters={"Price": "{:.2f}".format}
                    )
                )
            else:
                print(Fore.YELLOW + "  Order book data unavailable for display.")
            print(
                Fore.CYAN + Style.BRIGHT + "\n---------------------------------------"
            )
        else:
            print(Fore.RED + Style.BRIGHT + f"Could not fetch order book for {symbol}")
    except ccxt.ExchangeError as e:
        print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error: {e}")
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error fetching order book: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def list_available_symbols():
    """Lists available Futures trading symbols on Bybit."""
    if not EXCHANGE:
        print(Fore.RED + Style.BRIGHT + "CCXT Bybit client not initialized.")
        return

    try:
        markets = EXCHANGE.load_markets()
        futures_symbols = [
            symbol for symbol in markets if markets[symbol]["future"] == True
        ]
        os.system("clear")
        print(
            Fore.CYAN
            + Style.BRIGHT
            + "╔══════════"
            + Fore.GREEN
            + "AVAILABLE FUTURES SYMBOLS"
            + Fore.CYAN
            + "═══════════╗"
        )
        print(
            Fore.WHITE
            + Style.BRIGHT
            + "\nAvailable Futures Symbols on Bybit:\n"
            + Fore.GREEN
            + ", ".join(futures_symbols)
        )
        print(
            Fore.CYAN + Style.BRIGHT + "\n---------------------------------------"
        )
    except ccxt.ExchangeError as e:
        print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error: {e}")
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error fetching symbols: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def display_rsi():
    """Calculates and displays RSI for a given symbol and period using indicators.py."""
    if not EXCHANGE:
        print(Fore.RED + Style.BRIGHT + "CCXT Bybit client not initialized.")
        return

    symbol = input(Fore.YELLOW + "Enter Futures symbol (e.g., BTCUSDT): ").upper()
    period = int(input(Fore.YELLOW + "Enter RSI period (e.g., 14): "))
    timeframe = input(
        Fore.YELLOW + "Enter timeframe (e.g., 1h, 15m, 5m, 1m): "
    ).lower()

    try:
        ohlcv = EXCHANGE.fetch_ohlcv(symbol, timeframe, limit=period + 100)
        if not ohlcv:
            print(
                Fore.RED + Style.BRIGHT + f"Could not fetch OHLCV data for {symbol}"
            )
            return

        closes = [float(entry[4]) for entry in ohlcv]  # Ensure closing prices are floats
        if not closes:
            print(Fore.RED + Style.BRIGHT + "No closing prices available to calculate RSI.")
            return

        rsi_values = rsi(pd.Series(closes), period) # Pass Pandas Series for calculation

        if pd.isna(rsi_values[-1]): # Check for NaN before accessing last element
            print(Fore.YELLOW + Style.BRIGHT + "RSI calculation incomplete, not enough data.")
            return

        os.system("clear")
        print(
            Fore.CYAN
            + Style.BRIGHT
            + "╔═══════════════"
            + Fore.GREEN
            + "RSI INDICATOR"
            + Fore.CYAN
            + "════════════════╗"
        )
        print(
            Fore.WHITE
            + Style.BRIGHT
            + f"\nRSI ({period}) for {Fore.GREEN}{symbol}{Fore.WHITE} ({timeframe}): {Fore.GREEN}{rsi_values[-1]:.2f}"
        )
        if rsi_values[-1] > 70:
            print(Fore.RED + Style.BRIGHT + "  Overbought condition")
        elif rsi_values[-1] < 30:
            print(Fore.GREEN + Style.BRIGHT + "  Oversold condition")
        print(
            Fore.CYAN + Style.BRIGHT + "\n---------------------------------------"
        )

    except ccxt.ExchangeError as e:
        print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error: {e}")
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error calculating RSI: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def display_atr():
    """Calculates and displays ATR for a given symbol, period, and timeframe."""
    if not EXCHANGE:
        print(Fore.RED + Style.BRIGHT + "CCXT Bybit client not initialized.")
        return

    symbol = input(Fore.YELLOW + "Enter Futures symbol (e.g., BTCUSDT): ").upper()
    period = int(input(Fore.YELLOW + "Enter ATR period (e.g., 14): "))
    timeframe = input(
        Fore.YELLOW + "Enter timeframe (e.g., 1h, 15m, 5m, 1m): "
    ).lower()

    try:
        ohlcv = EXCHANGE.fetch_ohlcv(symbol, timeframe, limit=period + 100)
        if not ohlcv:
            print(
                Fore.RED + Style.BRIGHT + f"Could not fetch OHLCV data for {symbol}"
            )
            return

        highs = pd.Series([float(entry[2]) for entry in ohlcv])
        lows = pd.Series([float(entry[3]) for entry in ohlcv])
        closes = pd.Series([float(entry[4]) for entry in ohlcv])

        atr_values = ATR(highs, lows, closes, period)

        if pd.isna(atr_values.iloc[-1]): # Check for NaN before accessing last element
            print(Fore.YELLOW + Style.BRIGHT + "ATR calculation incomplete, not enough data.")
            return

        os.system("clear")
        print(
            Fore.CYAN
            + Style.BRIGHT
            + "╔═══════════════"
            + Fore.GREEN
            + "ATR INDICATOR"
            + Fore.CYAN
            + "════════════════╗"
        )
        print(
            Fore.WHITE
            + Style.BRIGHT
            + f"\nATR ({period}) for {Fore.GREEN}{symbol}{Fore.WHITE} ({timeframe}): {Fore.GREEN}{atr_values.iloc[-1]:.4f}"
        )
        print(
            Fore.CYAN + Style.BRIGHT + "\n---------------------------------------"
        )

    except ccxt.ExchangeError as e:
        print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error: {e}")
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error calculating ATR: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def display_fibonacci_pivot_points():
    """Displays Fibonacci Pivot Points for a given symbol and timeframe."""
    if not EXCHANGE:
        print(Fore.RED + Style.BRIGHT + "CCXT Bybit client not initialized.")
        return

    symbol = input(Fore.YELLOW + "Enter Futures symbol (e.g., BTCUSDT): ").upper()
    timeframe = input(
        Fore.YELLOW + "Enter timeframe for pivot points (e.g., 1d, 4h, 1h): "
    ).lower()

    try:
        ohlcv = EXCHANGE.fetch_ohlcv(symbol, timeframe, limit=1)  # Fetch only the latest OHLCV for pivot calculation
        if not ohlcv:
            print(
                Fore.RED + Style.BRIGHT + f"Could not fetch OHLCV data for {symbol}"
            )
            return

        high = ohlcv[0][2]
        low = ohlcv[0][3]
        close = ohlcv[0][4]

        pivots = FibonacciPivotPoints(high, low, close)

        os.system("clear")
        print(
            Fore.CYAN
            + Style.BRIGHT
            + "╔═══════════════"
            + Fore.GREEN
            + "FIBONACCI PIVOT POINTS"
            + Fore.CYAN
            + "══════════════╗"
        )
        print(
            Fore.WHITE
            + Style.BRIGHT
            + f"\nFibonacci Pivot Points for {Fore.GREEN}{symbol}{Fore.WHITE} ({timeframe}):"
        )
        print(Fore.CYAN + "-" * 40)
        print(Fore.WHITE + f"  Pivot (P): {Fore.GREEN}{pivots['Pivot']:.4f}")
        print(Fore.WHITE + f"  Resistance 1 (R1): {Fore.RED}{pivots['R1']:.4f}")
        print(Fore.WHITE + f"  Resistance 2 (R2): {Fore.RED}{pivots['R2']:.4f}")
        print(Fore.WHITE + f"  Resistance 3 (R3): {Fore.RED}{pivots['R3']:.4f}")
        print(Fore.WHITE + f"  Support 1 (S1): {Fore.GREEN}{pivots['S1']:.4f}")
        print(Fore.WHITE + f"  Support 2 (S2): {Fore.GREEN}{pivots['S2']:.4f}")
        print(Fore.WHITE + f"  Support 3 (S3): {Fore.GREEN}{pivots['S3']:.4f}")
        print(
            Fore.CYAN + Style.BRIGHT + "\n---------------------------------------"
        )

    except ccxt.ExchangeError as e:
        print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error: {e}")
    except Exception as e:
        print(Fore.RED + Style.BRIGHT + f"Error calculating Fibonacci Pivot Points: {e}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def debug_display_api_keys():
    """For debug purposes, displays loaded API keys (masked)."""
    os.system("clear")
    print(Fore.YELLOW + Style.BRIGHT + "DEBUG: Displaying API Keys (Masked)")
    masked_key = (
        BYBIT_API_KEY[:4] + "*" * (len(BYBIT_API_KEY) - 8) + BYBIT_API_KEY[-4:]
        if BYBIT_API_KEY
        else "Not Loaded"
    )
    masked_secret = (
        BYBIT_API_SECRET[:4] + "*" * (len(BYBIT_API_SECRET) - 8) + BYBIT_API_SECRET[-4:]
        if BYBIT_API_SECRET
        else "Not Loaded"
    )
    print(Fore.WHITE + f"API Key: {Fore.CYAN}{masked_key}")
    print(Fore.WHITE + f"API Secret: {Fore.CYAN}{masked_secret}")
    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


def main():
    """Main function to run the Bybit Futures Terminal."""
    while True:
        choice_main = display_main_menu()
        if choice_main == "1":
            while True:
                choice_account = view_account_menu()
                if choice_account == "1":
                    view_account_balance()
                elif choice_account == "2":
                    view_order_history()
                elif choice_account == "3":
                    print(Fore.YELLOW + Style.BRIGHT + "Simulated Deposit Feature - WIP")
                    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")
                elif choice_account == "4":
                    print(Fore.YELLOW + Style.BRIGHT + "Simulated Withdrawal Feature - WIP")
                    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")
                elif choice_account == "5":
                    break  # Back to main menu
                else:
                    print(
                        Fore.RED
                        + Style.BRIGHT
                        + "Invalid choice. Please enter a number between 1 and 5."
                    )
        elif choice_main == "2":
            while True:
                choice_market = display_market_menu()
                if choice_market == "1":
                    fetch_symbol_price()
                elif choice_market == "2":
                    get_order_book()
                elif choice_market == "3":
                    list_available_symbols()
                elif choice_market == "4":
                    display_rsi()
                elif choice_market == "5":
                    display_atr()
                elif choice_market == "6":  # New option
                    display_fibonacci_pivot_points()
                elif choice_market == "7":
                    break  # Back to main menu
                else:
                    print(
                        Fore.RED
                        + Style.BRIGHT
                        + "Invalid choice. Please enter a number between 1 and 7."
                    )
        elif choice_main == "3":
            if not EXCHANGE:
                print(
                    Fore.RED + Style.BRIGHT + "Trading actions require API keys to be set."
                )
                input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")
                continue

            while True:
                choice_trade = display_trading_menu()
                if choice_trade == "1":
                    place_market_order_requests()
                elif choice_trade == "2":
                    place_limit_order_requests()
                elif choice_trade == "3":
                    print(
                        Fore.YELLOW
                        + Style.BRIGHT
                        + "Cancel Order Feature (CCXT) - Work In Progress"
                    )
                    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")
                elif choice_trade == "4":
                    print(
                        Fore.YELLOW
                        + Style.BRIGHT
                        + "View Open Orders Feature (CCXT) - Work In Progress"
                    )
                    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")
                elif choice_trade == "5":
                    print(
                        Fore.YELLOW
                        + Style.BRIGHT
                        + "View Open Positions Feature (CCXT) - Work In Progress"
                    )
                    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")
                elif choice_trade == "6":
                    print(
                        Fore.YELLOW
                        + Style.BRIGHT
                        + "Trailing Stop (Simulated) - Work In Progress"
                    )
                    input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")
                elif choice_trade == "7":
                    break  # Back to main menu
                else:
                    print(
                        Fore.RED
                        + Style.BRIGHT
                        + "Invalid choice. Please enter a number between 1 and 7."
                    )
        elif choice_main == "4":
            debug_display_api_keys()
        elif choice_main == "5":
            print(Fore.MAGENTA + Style.BRIGHT + "Exiting terminal...")
            break
        else:
            print(
                Fore.RED
                + Style.BRIGHT
                + "Invalid choice. Please enter a number between 1 and 5."
            )


if __name__ == "__main__":
    # Check for indicators.py and create if not exists (with basic content)
    if not os.path.exists("indicators.py"):
        with open("indicators.py", 'w') as f:
            f.write("# indicators.py - Placeholder, you can add functions here\n\n")
            f.write("import pandas as pd\n\n")
            f.write("def rsi(close_prices, period):\n")
            f.write("    # Placeholder RSI function\n")
            f.write("    return pd.Series([50.0] * len(close_prices))\n\n")
            f.write("def ATR(high, low, close, period):\n")
            f.write("    # Placeholder ATR function\n")
            f.write("    return pd.Series([1.0] * len(high))\n\n")
            f.write("def FibonacciPivotPoints(high, low, close):\n")
            f.write("    # Placeholder Fibonacci Pivot Points\n")
            f.write("    pivots = {'Pivot': (high + low + close) / 3, 'R1': 0, 'R2': 0, 'R3': 0, 'S1': 0, 'S2': 0, 'S3': 0}\n")
            f.write("    return pivots\n")
        print(Fore.YELLOW + Style.BRIGHT + "Created placeholder indicators.py file. You may need to implement actual indicators.")

    main()
