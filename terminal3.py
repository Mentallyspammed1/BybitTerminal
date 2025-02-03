```python
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
           
