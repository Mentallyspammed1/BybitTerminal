#!/usr/bin/env python3
import os, time, hashlib, hmac, urllib.parse, json, threading, numpy as np, plotext as plt, smtplib, logging
from email.message import EmailMessage
import requests, pandas as pd, ccxt
from colorama import init, Fore, Style
from dotenv import load_dotenv
from datetime import datetime, timedelta
from indicators import FibonacciPivotPoints, RSI, ATR, atr
from enum import Enum  # Import Enum for order types/sides
from queue import Queue # Correct import for Queue (thread-safe queue)


init(autoreset=True);load_dotenv()

# --- Configuration Class ---
class Configuration:
    def __init__(self):
        self.api_key = os.getenv("BYBIT_API_KEY")
        self.api_secret = os.getenv("BYBIT_API_SECRET")
        self.email = {
            'server': os.getenv("EMAIL_SERVER"),
            'user': os.getenv("EMAIL_USER"),
            'password': os.getenv("EMAIL_PASSWORD"),
            'receiver': os.getenv("EMAIL_RECEIVER")
        }
        self.risk = {
            'max_per_trade': 0.02,
            'max_leverage': 100,
            'daily_loss_limit': 0.1
        }

CONFIG = Configuration()

# --- Logging Setup ---
logging.basicConfig(filename='terminal_errors.log', level=logging.ERROR,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# --- Enums for Order Types and Sides ---
class OrderType(Enum):
    MARKET = 'market'
    LIMIT = 'limit'
    STOP_LIMIT = 'limit' # For stop-limit, base type is limit

class OrderSide(Enum):
    BUY = 'buy'
    SELL = 'sell'

class BTT:
    """Bybit Terminal Trader - Command-line interface for trading Bybit Futures."""
    def __init__(self):
        """Initializes BTT terminal."""
        self.exch = self._init_exch()
        self.rm = RM(CONFIG.risk)
        self.ntf = NH(CONFIG.email)
        self.se = SE()
        self.ao = {}
        self.mdc = {}
        self.fpp_indicator = FibonacciPivotPoints(config={})

    def _init_exch(self) -> ccxt.Exchange:
        """Initializes CCXT Bybit exchange object."""
        if not CONFIG.api_key or not CONFIG.api_secret:
            raise ValueError("API keys missing from environment variables.")
        return ccxt.bybit({
            'apiKey': CONFIG.api_key,
            'secret': CONFIG.api_secret,
            'options': {'defaultType': 'swap'}
        })

    def execute_order(self, order_type: OrderType, symbol: str, side: OrderSide, amount: float, price: float = None, params: dict = None):
        """Executes a trading order on Bybit."""
        try:
            op = {'symbol': symbol, 'type': order_type.value, 'side': side.value, 'amount': amount, 'params': params or {}}
            if order_type == OrderType.LIMIT:
                op['price'] = price
            order = self.exch.create_order(**op)
            self.ao[order['id']] = order
            self.ntf.send_alert(f"Order executed: {order['id']}")
            return order
        except ccxt.NetworkError as e:
            error_msg = f"Network error encountered: {str(e)}"
            self.ntf.send_alert(error_msg)
            logging.error(error_msg)
        except ccxt.ExchangeError as e:
            error_msg = f"Exchange error encountered: {str(e)}"
            self.ntf.send_alert(error_msg)
            logging.error(error_msg)
            return None
        except Exception as e:
            error_msg = f"Unexpected error during order execution: {str(e)}"
            self.ntf.send_alert(error_msg)
            logging.error(error_msg)
            return None

    def cond_order(self):
        """Handles conditional order placement based on user selection."""
        print(Fore.CYAN + "\nCond Order Types:\n1. Stop-Limit\n2. Trailing Stop\n3. OCO")
        choice = input(Fore.YELLOW + "Select type: ")

        symbol = input(Fore.YELLOW + "Symbol: ").upper()
        side_str = input(Fore.YELLOW + "Side (buy/sell): ").lower()
        side = OrderSide(side_str)
        amount = float(input(Fore.YELLOW + "Quantity: "))

        if choice == '1':
            stop_price = float(input(Fore.YELLOW + "Stop Price: "))
            limit_price = float(input(Fore.YELLOW + "Limit Price: "))
            self._sl(symbol, side, amount, stop_price, limit_price)
        elif choice == '2':
            trail_value = float(input(Fore.YELLOW + "Trailing Value ($): "))
            self._ts(symbol, side, amount, trail_value)
        elif choice == '3':
            price1 = float(input(Fore.YELLOW + "Price 1: "))
            price2 = float(input(Fore.YELLOW + "Price 2: "))
            self._oco(symbol, side, amount, price1, price2)
        else:
            print(Fore.RED + Style.BRIGHT + "Invalid choice for conditional order type.")

    def _sl(self, symbol: str, side: OrderSide, amount: float, stop: float, limit: float):
        """Places a stop-limit order."""
        params = {'stopPrice': stop, 'price': limit, 'type': 'STOP'}
        try:
            order = self.exch.create_order(symbol=symbol, type='limit', side=side.value, amount=amount, price=limit, params=params)
            print(Fore.GREEN + f"Stop-limit placed: {order['id']}")
        except Exception as e:
            print(Fore.RED + f"Error placing stop-limit order: {e}")
            logging.error(f"Stop-limit order placement error: {e}")

    def chart_adv(self, symbol: str, timeframe: str = '1h', periods: int = 100):
        """Displays an advanced price chart with optional RSI overlay."""
        ohlcv = self.exch.fetch_ohlcv(symbol, timeframe, limit=periods)
        closes = [x[4] for x in ohlcv]
        plt.clear_figure()
        plt.plot(closes)
        plt.title(f"{symbol} Price Chart ({timeframe})")
        plt.show()
        overlay_rsi = input(Fore.YELLOW + "Overlay RSI? (y/n): ").lower()
        if overlay_rsi == 'y':
            self._chart_rsi(closes)

    def _chart_rsi(self, closes: list):
        """Overlays RSI on the existing chart."""
        rsi_indicator = RSI(config={})  # Instantiate RSI class with a config (empty dictionary)
        rsi_vals = rsi_indicator.calculate(pd.Series(closes), period=14) # Call the calculate method
        plt.plot(rsi_vals, color='red')
        plt.ylim(0, 100)
        plt.show()

    def backtest(self):
        """Initiates and displays backtesting results."""
        symbol = input(Fore.YELLOW + "Symbol: ").upper()
        timeframe = input(Fore.YELLOW + "Timeframe (1h/4h/1d): ")
        strategy_name = input(Fore.YELLOW + "Strategy (ema/macd): ").lower()

        try:
            data = self.exch.fetch_ohlcv(symbol, timeframe, limit=1000)
            if not data:
                print(Fore.RED + "No data available for backtesting.")
                return

            df = pd.DataFrame(data, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
            df.set_index('timestamp', inplace=True)
            bt_res = self.se.run_backtest(df, strategy_name)
            print(Fore.CYAN + f"\n--- Backtest Results ({strategy_name.upper()}):")
            print(Fore.WHITE + f"Total Return: {Fore.GREEN}{bt_res['tot_ret_perc']:.2f}%")
            print(Fore.WHITE + f"Max Drawdown: {Fore.RED}{bt_res['max_dd_perc']:.2f}%")

            plot_cumulative_returns = input(Fore.YELLOW + "Plot cumulative returns? (y/n): ").lower()
            if plot_cumulative_returns == 'y':
                plt.clear_figure()
                plt.plot(bt_res['cum_rets'].fillna(0))
                plt.title(f"{strategy_name.upper()} Strategy Cumulative Returns for {symbol}")
                plt.xlabel("Date")
                plt.ylabel("Cumulative Returns")
                plt.show()

        except ccxt.ExchangeError as e:
            print(Fore.RED + f"Bybit Exchange Error during backtest: {e}")
            logging.error(f"Bybit Exchange Error during backtest: {e}")
        except ValueError as e:
            print(Fore.RED + str(e))
            logging.error(f"Value Error during backtest: {e}")
        except Exception as e:
            print(Fore.RED + f"Backtest Error: {e}")
            logging.error(f"General Backtest Error: {e}")
    def disp_adv_menu(self):
        """Displays the advanced features menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔═══════════════════════════════╗\n║      ADVANCED FEATURES        ║\n╠═══════════════════════════════╣\n║ 1. Algorithmic Trading        ║\n║ 2. Risk Management Tools      ║\n║ 3. Market Analysis Suite      ║\n║ 4. Notification Setup         ║\n║ 5. Back to Main Menu          ║\n╚═══════════════════════════════╝\n""")
            choice = input(Fore.YELLOW + "Select feature (1-5): ")
            if choice == '1':
                self.disp_algo_menu()
            elif choice == '2':
                self.disp_rm_menu()
            elif choice == '3':
                self.disp_ma_menu()
            elif choice == '4':
                self.disp_notif_menu()
            elif choice == '5':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 5.")
                time.sleep(1.5)

    def disp_rm_menu(self):
        """Displays the risk management tools menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔═══════════════════════════════╗\n║    RISK MANAGEMENT TOOLS      ║\n╠═══════════════════════════════╣\n║ 1. Margin Calculator          ║\n║ 2. Set Max Risk Percentage    ║\n║ 3. Set Leverage Configuration ║\n║ 4. Back to Advanced Features  ║\n╚═══════════════════════════════╝\n""")
            choice = input(Fore.YELLOW + "Select tool (1-4): ")
            if choice == '1':
                self.margin_calc()
            elif choice == '3':
                self.set_lev_menu()
            elif choice == '4':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 4.")
                time.sleep(1.5)

    def disp_algo_menu(self):
        """Displays the algorithmic trading menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔═══════════════════════════════╗\n║    ALGORITHMIC TRADING        ║\n╠═══════════════════════════════╣\n║ 1. Run Strategy Backtest      ║\n║ 2. Live Strategy Exec (WIP)   ║\n║ 3. Strategy Config (WIP)    ║\n║ 4. Back to Advanced Features  ║\n╚═══════════════════════════════╝\n""")
            choice = input(Fore.YELLOW + "Select action (1-4): ")
            if choice == '1':
                self.backtest()
            elif choice == '4':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 4.")
                time.sleep(1.5)

    def disp_ma_menu(self):
        """Displays the market analysis suite menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔═══════════════════════════════╗\n║    MARKET ANALYSIS SUITE      ║\n╠═══════════════════════════════╣\n║ 1. Adv Chart     ║\n║ 2. Mkt Sentiment       ║\n║ 3. Funding Rate           ║\n║ 4. ST Analyze         ║
║ 5. BB Analyze    ║
║ 6. MACD Analyze        ║
║ 7. FPP Analyze         ║
║ 8. Back to Adv Feat  ║\n╚═══════════════════════════════╝\n""")
            choice = input(Fore.YELLOW + "Select analysis (1-8): ")
            if choice == '1':
                symbol = input(Fore.YELLOW + "Enter symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Enter timeframe: ").lower()
                self.chart_adv(symbol, timeframe)
            elif choice == '2':
                sentiment = get_msentiment()
                print(Fore.CYAN + "\nMarket Sentiment (Fear/Greed Index):")
                print(Fore.WHITE + f"{sentiment}")
                input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")
            elif choice == '3':
                symbol = input(Fore.YELLOW + "Enter symbol: ").upper()
                self.fetch_frate(symbol)
            elif choice == '7':
                self.analyze_fpp_menu()
            elif choice == '8':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 8.")
                time.sleep(1.5)

    def disp_notif_menu(self):
        """Displays the notification setup menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔═══════════════════════════════╗\n║    NOTIFICATION SETUP         ║\n╠═══════════════════════════════╣\n║ 1. Set Price Alert            ║\n║ 2. Cfg Email Alerts     ║\n║ 3. Back to Adv Feat  ║\n╚═══════════════════════════════╝\n""")
            choice = input(Fore.YELLOW + "Select action (1-3): ")
            if choice == '1':
                symbol = input(Fore.YELLOW + "Symbol for alert: ").upper()
                price = float(input(Fore.YELLOW + "Target price: "))
                self.ntf.price_alert(symbol, price)
                print(Fore.GREEN + f"Price alert set for {symbol} at {price}.")
                input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")
            elif choice == '2':
                self.cfg_email_menu()
            elif choice == '3':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 3.")
                time.sleep(1.5)

    def cfg_email_menu(self):
        """Configures email alert settings."""
        print(Fore.CYAN + Style.BRIGHT + "\n--- Configure Email Alerts ---")
        server = input(Fore.YELLOW + "SMTP Server (e.g., smtp.gmail.com): ")
        user = input(Fore.YELLOW + "Email User: ")
        password = input(Fore.YELLOW + "Email Pass: ")
        smtp_details = {'server': server, 'user': user, 'password': password}
        self.ntf.cfg_email(smtp_details)
        input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def margin_calc(self):
        """Calculates margin requirements for a trade."""
        os.system('clear')
        print(Fore.CYAN + Style.BRIGHT + "╔══════════════════════════════════╗\n║        MARGIN CALCULATOR         ║\n╚══════════════════════════════════╝")
        account_balance = float(input(Fore.YELLOW + "Account Balance (USDT): "))
        leverage = int(input(Fore.YELLOW + "Leverage (e.g., 10x): "))
        risk_percentage = float(input(Fore.YELLOW + "Risk % per trade: "))
        entry_price = float(input(Fore.YELLOW + "Entry Price: "))
        stop_loss_price = float(input(Fore.YELLOW + "Stop Loss Price: "))

        self.rm.set_lev(leverage)
        position_size = self.rm.pos_size(entry_price, stop_loss_price, account_balance)
        print(Fore.CYAN + "\n--- Position Calculation ---")
        print(Fore.WHITE + f"Position Size (Contracts): {Fore.GREEN}{position_size}")
        risk_amount = account_balance * risk_percentage / 100
        print(Fore.WHITE + f"Risk Amount (USDT): ${Fore.YELLOW}{risk_amount:.2f}")
        print(Fore.WHITE + f"Leverage Used: {Fore.MAGENTA}{leverage}x")
        input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def set_lev_menu(self):
        """Sets the leverage configuration through user input."""
        leverage = int(input(Fore.YELLOW + "Set Leverage (1-100): "))
        self.rm.set_lev(leverage)
        print(Fore.GREEN + f"Leverage set to {self.rm.leverage}x")
        input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def fetch_frate(self, symbol: str):
        """Fetches and displays the funding rate for a given symbol."""
        if not self.exch:
            print(Fore.RED + Style.BRIGHT + "CCXT exchange object not initialized.")
            return None

        try:
            funding_rate_data = self.exch.fetch_funding_rate(symbol)
            if funding_rate_data and 'fundingRate' in funding_rate_data:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + "╔════════════FUNDING RATE═════════════╗")
                rate_percentage = float(funding_rate_data['fundingRate']) * 100
                print(Fore.WHITE + Style.BRIGHT + f"\nCurrent funding rate for {Fore.GREEN}{symbol}{Fore.WHITE}: {Fore.GREEN}{rate_percentage:.4f}%")

                if rate_percentage > 0:
                    rate_color = Fore.GREEN
                    direction = "Positive"
                elif rate_percentage < 0:
                    rate_color = Fore.RED
                    direction = "Negative"
                else:
                    rate_color = Fore.YELLOW
                    direction = "Neutral"

                print(Fore.WHITE + Style.BRIGHT + f"Funding Rate is: {rate_color}{direction}{Fore.WHITE}")
                return funding_rate_data['fundingRate']
            else:
                print(Fore.RED + Style.BRIGHT + f"Could not fetch funding rate for {symbol}")
                return None

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error fetching funding rate: {e}")
            logging.error(f"Bybit Exchange Error fetching funding rate: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error fetching funding rate: {e}")
            logging.error(f"General error fetching funding rate: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def analyze_fpp_menu(self):
        """Analyzes and displays Fibonacci Pivot Points based on user input."""
        symbol = input(Fore.YELLOW + "Enter Futures symbol for FPP analysis (e.g., BTCUSDT): ").upper()
        timeframe = input(Fore.YELLOW + "Enter timeframe for FPP (e.g., 1d): ").lower()

        try:
            bars = self.exch.fetch_ohlcv(symbol, timeframe, limit=2)
            if not bars or len(bars) < 2:
                print(Fore.RED + Style.BRIGHT + f"Could not fetch enough OHLCV data for {symbol} in {timeframe}")
                return

            df = pd.DataFrame(bars, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            current_price = self.exch.fetch_ticker(symbol)['last']
            fpp_df = self.fpp_indicator.calculate(df)
            signals = self.fpp_indicator.generate_trading_signals(df, current_price)

            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + f"╔══════FIBONACCI PIVOT POINTS ({symbol} - {timeframe})══════╗")
            print(Fore.WHITE + Style.BRIGHT + "\nFibonacci Pivot Levels:")
            for level in self.fpp_indicator.level_names:
                price = fpp_df.iloc[0][level]
                signal_name = self.fpp_indicator.level_names[level]
                print(f"{Fore.WHITE}{signal_name}: {Fore.GREEN}{price:.4f}")

            if signals:
                print(Fore.WHITE + Style.BRIGHT + "\nTrading Signals:")
                for signal in signals:
                    print(signal)
            else:
                print(Fore.YELLOW + "\nNo strong signals at this time.")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error during FPP analysis: {e}")
            logging.error(f"Bybit Exchange Error during FPP analysis: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error analyzing Fibonacci Pivot Points: {e}")
            logging.error(f"General error analyzing Fibonacci Pivot Points: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")

    def disp_mkt_menu(self):
        """Displays the market data menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔════════════MARKET DATA═════════════╗\n║         (Using CCXT)             ║\n╚═══════════════════════════════╝\nChoose data:\n1. Symbol Price\n2. Order Book\n3. Symbols List\n4. RSI\n5. ATR\n6. FPP\n7. Adv Chart\n8. Mkt Sentiment\n9. Funding Rate\n10. Back to Main Menu\n""")
            choice = input(Fore.YELLOW + "Select data (1-10): ")
            if choice == '1':
                symbol = input(Fore.YELLOW + "Futures symbol (e.g., BTCUSDT): ").upper()
                self.fetch_sym_price(symbol)
            elif choice == '2':
                symbol = input(Fore.YELLOW + "Futures symbol (e.g., BTCUSDT): ").upper()
                self.get_ob(symbol)
            elif choice == '3':
                self.list_syms()
            elif choice == '4':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe (e.g., 1h): ").lower()
                self.disp_rsi(symbol, timeframe)
            elif choice == '5':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe (e.g., 1h): ").lower()
                period = int(input(Fore.YELLOW + "ATR Period (e.g., 14): ") or 14)
                self.disp_atr(symbol, timeframe, period)
            elif choice == '6':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe for FPP (e.g., 1d): ").lower()
                self.disp_fpp(symbol, timeframe)
            elif choice == '7':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe (e.g., 1h): ").lower()
                self.chart_adv(symbol, timeframe)
            elif choice == '8':
                sentiment = get_msentiment()
                print(Fore.CYAN + "\nMarket Sentiment (Fear/Greed Index):")
                print(Fore.WHITE + f"{sentiment}")
                input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")
            elif choice == '9':
                symbol = input(Fore.YELLOW + "Enter symbol: ").upper()
                self.fetch_frate(symbol)
            elif choice == '10':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 10.")
                time.sleep(1.5)

    def disp_fpp(self, symbol: str, timeframe: str):
        """Displays Fibonacci Pivot Points in a formatted output."""
        try:
            bars = self.exch.fetch_ohlcv(symbol, timeframe, limit=2)
            if not bars or len(bars) < 2:
                print(Fore.RED + Style.BRIGHT + f"Could not fetch enough OHLCV data for {symbol} in {timeframe}")
                return

            df = pd.DataFrame(bars, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            fpp_df = self.fpp_indicator.calculate(df)

            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + f"╔══════FIBONACCI PIVOT POINTS ({symbol} - {timeframe})══════╗")
            print(Fore.WHITE + Style.BRIGHT + "\nFibonacci Pivot Levels:")
            for level in self.fpp_indicator.level_names:
                price = fpp_df.iloc[0][level]
                signal_name = self.fpp_indicator.level_names[level]
                print(f"{Fore.WHITE}{signal_name}: {Fore.GREEN}{price:.4f}")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error during FPP display: {e}")
            logging.error(f"Bybit Exchange Error during FPP display: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error displaying Fibonacci Pivot Points: {e}")
            logging.error(f"General error displaying Fibonacci Pivot Points: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")

    def disp_trade_menu(self):
        """Displays the trading actions menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔════════════TRADE ACTIONS════════════╗\n║      (Using Direct Requests)      ║\n╚═══════════════════════════════╝\nChoose action:\n1. Market Order\n2. Limit Order\n3. Cond Order\n4. Cancel Order\n8. Back to Main Menu\n""")
            choice = input(Fore.YELLOW + "Select action (1-8): ")
            if choice == '1':
                self.place_mkt_order()
            elif choice == '2':
                self.place_lmt_order()
            elif choice == '3':
                self.cond_order()
            elif choice == '4':
                self.cancel_order_menu()
            elif choice == '8':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 8.")
                time.sleep(1.5)

    def cancel_order_menu(self):
        """Handles order cancellation based on user input."""
        order_id_to_cancel = input(Fore.YELLOW + "Enter Order ID to Cancel: ")
        symbol_for_cancel = input(Fore.YELLOW + "Enter Symbol for Order Cancellation: ").upper()
        confirmation = input(Fore.YELLOW + Style.BRIGHT + f"Confirm cancel order {order_id_to_cancel} for {symbol_for_cancel}? (y/n): ").lower()
        if confirmation == 'y':
            try:
                result = self.exch.cancel_order(order_id_to_cancel, symbol=symbol_for_cancel)
                print(Fore.GREEN + f"Order {order_id_to_cancel} cancelled successfully.")
                self.ntf.send_alert(f"Order {order_id_to_cancel} cancelled.")
            except ccxt.OrderNotFound as e:
                print(Fore.RED + Style.BRIGHT + f"Order not found: {e}")
                logging.error(f"Order not found during cancellation: {e}")
            except ccxt.ExchangeError as e:
                print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error during order cancellation: {e}")
                logging.error(f"Bybit Exchange Error during order cancellation: {e}")
            except Exception as e:
                print(Fore.RED + Style.BRIGHT + f"Error cancelling order: {e}")
                logging.error(f"General error during order cancellation: {e}")
        else:
            print(Fore.YELLOW + "Order cancellation aborted by user.")
        input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")

    def disp_acc_menu(self):
        """Displays the account operations menu."""
        while True:
            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + """\n╔════════════ACCOUNT OPS═════════════╗\n║     (Using CCXT & Pandas)        ║\n╚═══════════════════════════════╝\nChoose action:\n1. View Balance\n2. View Order History\n3. Margin Calculator\n4. View Open Orders\n6. Back to Main Menu\n""")
            choice = input(Fore.YELLOW + "Select action (1-6): ")
            if choice == '1':
                self.view_bal()
            elif choice == '2':
                self.view_ord_hist()
            elif choice == '3':
                self.margin_calc()
            elif choice == '4':
                self.view_open_orders()
            elif choice == '6':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 6.")
                time.sleep(1.5)

    def view_open_orders(self):
        """Displays current open orders for a specified symbol."""
        symbol = input(Fore.YELLOW + "Enter Futures symbol to view open orders (e.g., BTCUSDT, leave blank for all): ").upper()
        try:
            if symbol:
                open_orders = self.exch.fetch_open_orders(symbol=symbol)
            else:
                open_orders = self.exch.fetch_open_orders()
            if open_orders:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + f"╔══════════OPEN ORDERS ({symbol if symbol else 'ALL SYMBOLS'})══════════╗")
                df_orders = pd.DataFrame(open_orders, columns=['id', 'datetime', 'type', 'side', 'price', 'amount', 'status', 'symbol'])
                df_orders['datetime'] = pd.to_datetime(df_orders['datetime']).dt.strftime('%Y-%m-%d %H:%M:%S')
                print(Fore.WHITE + Style.BRIGHT + "\nOpen Orders:")
                print(Fore.GREEN + df_orders[['datetime', 'symbol', 'type', 'side', 'price', 'amount', 'status']].to_string(index=False))
            else:
                print(Fore.YELLOW + "No open orders found.")
        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Err fetch open orders: {e}")
            logging.error(f"Bybit Exchange Error fetching open orders: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Err view open orders: {e}")
            logging.error(f"General error viewing open orders: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")


    def disp_main_menu(self):
        """Displays the main menu of the terminal."""
        os.system('clear')
        print(Fore.CYAN + Style.BRIGHT + """\n╔══════════════════════════════════╗\n║   Bybit Futures Terminal v1.1    ║\n║  Enhanced Version - Pyrrmethus Edit   ║\n║       Powered by Pyrrmethus       ║\n╚══════════════════════════════════╝\nChoose a category:\n1. Account Operations\n2. Market Data\n3. Trading Actions\n4. Advanced Features\n5. Display API Keys (Debug)\n6. Exit\n""")
        return input(Fore.YELLOW + Style.BRIGHT + "Enter choice (1-6): ")

    def handle_acc_menu(self):
        """Handles actions within the account operations menu."""
        while True:
            choice_acc = self.disp_acc_menu()
            if choice_acc == '1':
                self.view_bal()
            elif choice_acc == '2':
                self.view_ord_hist()
            elif choice_acc == '3':
                self.margin_calc()
            elif choice_acc == '4':
                self.view_open_orders()
            elif choice_acc == '6':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 6.")

    def handle_mkt_menu(self):
        """Handles actions within the market data menu."""
        while True:
            choice_mkt = self.disp_mkt_menu()
            if choice_mkt == '1':
                symbol = input(Fore.YELLOW + "Futures symbol (e.g., BTCUSDT): ").upper()
                self.fetch_sym_price(symbol)
            elif choice_mkt == '2':
                symbol = input(Fore.YELLOW + "Futures symbol (e.g., BTCUSDT): ").upper()
                self.get_ob(symbol)
            elif choice_mkt == '3':
                self.list_syms()
            elif choice_mkt == '4':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe (e.g., 1h): ").lower()
                self.disp_rsi(symbol, timeframe)
            elif choice_mkt == '5':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe (e.g., 1h): ").lower()
                period = int(input(Fore.YELLOW + "ATR Period (e.g., 14): ") or 14)
                self.disp_atr(symbol, timeframe, period)
            elif choice_mkt == '6':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe for FPP (e.g., 1d): ").lower()
                self.disp_fpp(symbol, timeframe)
            elif choice_mkt == '7':
                symbol = input(Fore.YELLOW + "Futures symbol: ").upper()
                timeframe = input(Fore.YELLOW + "Timeframe (e.g., 1h): ").lower()
                self.chart_adv(symbol, timeframe)
            elif choice_mkt == '8':
                sentiment = get_msentiment()
                print(Fore.CYAN + "\nMarket Sentiment (Fear/Greed Index):")
                print(Fore.WHITE + f"{sentiment}")
                input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")
            elif choice_mkt == '9':
                symbol = input(Fore.YELLOW + "Enter symbol: ").upper()
                self.fetch_frate(symbol)
            elif choice_mkt == '10':
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 10.")

    def handle_trade_menu(self):
        """Handles actions within the trading actions menu."""
        if CONFIG.api_key and CONFIG.api_secret:
            while True:
                choice_trade = self.disp_trade_menu()
                if choice_trade == '1':
                    self.place_mkt_order()
                elif choice_trade == '2':
                    self.place_lmt_order()
                elif choice_trade == '3':
                    self.cond_order()
                elif choice_trade == '4':
                    self.cancel_order_menu()
                elif choice_trade == '8':
                    break
                else:
                    print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 8.")
        else:
            print(Fore.RED + Style.BRIGHT + "Trading actions disabled: API keys missing.")
            input(Fore.YELLOW + Style.BRIGHT + "Press Enter...")

    def main(self):
        """Main loop of the terminal application."""
        while True:
            main_choice = self.disp_main_menu()
            if main_choice == '1':
                self.handle_acc_menu()
            elif main_choice == '2':
                self.handle_mkt_menu()
            elif main_choice == '3':
                self.handle_trade_menu()
            elif main_choice == '4':
                self.disp_adv_menu()
            elif main_choice == '5':
                self.debug_apikeys()
            elif main_choice == '6':
                print(Fore.MAGENTA + Style.BRIGHT + "Exiting terminal.")
                break
            else:
                print(Fore.RED + Style.BRIGHT + "Invalid choice. Please select a number from 1 to 6.")
                time.sleep(1.5)
        print(Fore.CYAN + Style.BRIGHT + "Terminal closed.")

    def view_bal(self):
        """Displays the account balance."""
        if not self.exch:
            print(Fore.Red + Style.BRIGHT + "CCXT exchange object not initialized.")
            return
        try:
            balance_data = self.exch.fetch_balance()
            if balance_data and "USDT" in balance_data and isinstance(balance_data["USDT"], dict):
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + "╔═══════════ACCOUNT BALANCE════════════╗")
                usdt_balance = balance_data.get("USDT", {})
                total_balance = usdt_balance.get("total", float('nan'))
                free_balance = usdt_balance.get("free", float('nan'))
                df_balance = pd.DataFrame([{"currency": "USDT", "total": total_balance, "free": free_balance}])
                if not df_balance.empty and not df_balance[["total", "free"]].isnull().all().all():
                    print(Fore.WHITE + Style.BRIGHT + "\nBalances (USDT Perpetual Futures):")
                    print(Fore.GREEN + df_balance[["currency", "total", "free"]].to_string(index=False, formatters={"total": "{:.4f}".format, "free": "{:.4f}".format}))
                else:
                    print(Fore.YELLOW + "USDT balance information unavailable.")
                print(Fore.CYAN + Style.BRIGHT + "\n---------------------------------------")
            else:
                print(Fore.YELLOW + "Could not retrieve balance information.")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error fetching balance: {e}")
            logging.error(f"Bybit Exchange Error fetching balance: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error fetching balance: {e}")
            logging.error(f"General error fetching balance: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def view_ord_hist(self):
        """Displays order history for a specified symbol."""
        if not self.exch:
            print(Fore.Red + Style.BRIGHT + "CCXT exchange object not initialized.")
            return
        try:
            symbol = input(Fore.YELLOW + "Futures symbol (e.g., BTC/USDT): ").upper()
            limit = int(input(Fore.YELLOW + f"Number of orders to view (max 20, default 5): ") or 5)
            limit = min(limit, 20)
            order_history = self.exch.fetch_orders(symbol=symbol, limit=limit)
            if order_history:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + f"╔══════════ORDER HISTORY ({symbol})══════════╗")
                df_orders = pd.DataFrame(order_history, columns=['id', 'datetime', 'type', 'side', 'price', 'amount', 'status'])
                df_orders['datetime'] = pd.to_datetime(df_orders['datetime']).dt.strftime('%Y-%m-%d %H:%M:%S')
                print(Fore.WHITE + Style.BRIGHT + "\nLast {} Orders:".format(limit))
                print(Fore.GREEN + df_orders[['datetime', 'type', 'side', 'price', 'amount', 'status']].to_string(index=False))
            else:
                print(Fore.YELLOW + "No order history available or invalid symbol.")
        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Err fetch order history: {e}")
            logging.error(f"Bybit Exchange Error fetching order history: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error viewing order history: {e}")
            logging.error(f"General error viewing order history: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def fetch_sym_price(self, symbol: str):
        """Fetches and displays the current price of a symbol."""
        if not self.exch:
            print(Fore.Red + Style.BRIGHT + "CCXT exchange object not initialized.")
            return
        try:
            ticker_data = self.exch.fetch_ticker(symbol)
            if ticker_data and 'last' in ticker_data:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + f"╔═══════════PRICE ({symbol})════════════╗")
                price = ticker_data['last']
                print(Fore.WHITE + Style.BRIGHT + f"\nCurrent price of {Fore.GREEN}{symbol}{Fore.WHITE}: {Fore.GREEN}{price:.2f}")
                if ticker_data['bid'] and ticker_data['ask']:
                    bid_price = ticker_data['bid']
                    ask_price = ticker_data['ask']
                    print(Fore.WHITE + Style.BRIGHT + f"Bid: {Fore.GREEN}{bid_price:.2f}, Ask: {Fore.RED}{ask_price:.2f}")
                else:
                    print(Fore.YELLOW + "Bid/Ask prices not available.")
                print(Fore.CYAN + Style.BRIGHT + "\n---------------------------------------")
            else:
                print(Fore.YELLOW + f"Could not retrieve ticker data for {symbol}.")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error fetching price: {e}")
            logging.error(f"Bybit Exchange Error fetching price: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error fetching price: {e}")
            logging.error(f"General error fetching price: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def get_ob(self, symbol: str):
        """Fetches and displays the order book for a symbol."""
        if not self.exch:
            print(Fore.RED + Style.BRIGHT + "CCXT exchange object not initialized.")
            return
        try:
            order_book_data = self.exch.fetch_order_book(symbol, limit=10)
            if order_book_data and 'bids' in order_book_data and 'asks' in order_book_data:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + f"╔══════════ORDER BOOK ({symbol})══════════╗")
                print(Fore.WHITE + Style.BRIGHT + "\nTop 10 Bids:")
                for bid in order_book_data['bids']:
                    print(Fore.GREEN + f"Price: {bid[0]:.2f}, Volume: {bid[1]:.2f}")
                print(Fore.WHITE + Style.BRIGHT + "\nTop 10 Asks:")
                for ask in order_book_data['asks']:
                    print(Fore.RED + f"Price: {ask[0]:.2f}, Volume: {ask[1]:.2f}")
                print(Fore.CYAN + Style.BRIGHT + "\n---------------------------------------")
            else:
                print(Fore.YELLOW + f"Could not retrieve order book data for {symbol}.")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error fetching order book: {e}")
            logging.error(f"Bybit Exchange Error fetching order book: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error fetching order book: {e}")
            logging.error(f"General error fetching order book: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def list_syms(self):
        """Lists available symbols on Bybit."""
        if not self.exch:
            print(Fore.RED + Style.BRIGHT + "CCXT exchange object not initialized.")
            return
        try:
            markets_data = self.exch.load_markets()
            if markets_data:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + "╔══════════AVAILABLE SYMBOLS═══════════╗")
                print(Fore.WHITE + Style.BRIGHT + "\nAvailable Futures Symbols on Bybit:")
                symbol_list = [sym for sym in self.exch.symbols if sym.endswith('/USDT') and 'swap' in self.exch.markets[sym]['info']['category']]
                symbol_list.sort()
                for sym in symbol_list:
                    print(Fore.GREEN + f"{sym}", end=', ')
                print(Fore.CYAN + Style.BRIGHT + "\n---------------------------------------")
            else:
                print(Fore.YELLOW + "Could not load market symbols.")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error listing symbols: {e}")
            logging.error(f"Bybit Exchange Error listing symbols: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error listing symbols: {e}")
            logging.error(f"General error listing symbols: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def disp_rsi(self, symbol: str, timeframe: str):
        """Displays RSI for a given symbol and timeframe."""
        try:
            ohlcv_data = self.exch.fetch_ohlcv(symbol, timeframe, limit=150)
            closes_data = [x[4] for x in ohlcv_data]
            rsi_values = RSI(pd.Series(closes_data), 14)
            if not rsi_values.empty:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + f"╔══════════════RSI ({symbol} - {timeframe})═════════════╗")
                last_rsi_value = rsi_values.iloc[-1]
                overbought_threshold = 70
                oversold_threshold = 30
                print(Fore.WHITE + Style.BRIGHT + f"\nLast RSI ({timeframe}): {Fore.MAGENTA}{last_rsi_value:.2f}")

                if last_rsi_value >= overbought_threshold:
                    print(Fore.RED + Style.BRIGHT + f"Overbought (>= {overbought_threshold})")
                elif last_rsi_value <= oversold_threshold:
                    print(Fore.GREEN + Style.BRIGHT + f"Oversold (<= {oversold_threshold})")
                else:
                    print(Fore.YELLOW + Style.BRIGHT + "Neutral")

                plt.clear_figure()
                plt.plot(rsi_values.values)
                plt.title(f'RSI for {symbol} ({timeframe})')
                plt.ylim(0, 100)
                plt.show()
                print(Fore.CYAN + Style.BRIGHT + "\n---------------------------------------")
            else:
                print(Fore.YELLOW + f"Could not calculate RSI for {symbol} in {timeframe}.")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error displaying RSI: {e}")
            logging.error(f"Bybit Exchange Error displaying RSI: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error displaying RSI: {e}")
            logging.error(f"General error displaying RSI: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    
    def disp_atr(self, symbol: str, timeframe: str, period: int):
        """Displays ATR for a given symbol, timeframe, and period."""
        try:
            ohlcv_data = self.exch.fetch_ohlcv(symbol, timeframe, limit=150)
            df_ohlcv = pd.DataFrame(ohlcv_data, columns=['ts', 'open', 'high', 'low', 'close', 'volume'])

            atr_config = {"length": period}
            atr_indicator = ATR(atr_config)

            atr_df = atr_indicator.calculate(df_ohlcv)

            if not atr_df.empty and f'atr_sma_{period}' in atr_df.columns or f'atr_ema_{period}' in atr_df.columns:
                os.system('clear')
                print(Fore.CYAN + Style.BRIGHT + f"╔══════════════ATR ({symbol} - {timeframe})═════════════╗")

                atr_column_name = f'atr_sma_{period}' if f'atr_sma_{period}' in atr_df.columns else f'atr_ema_{period}'
                last_atr_value = atr_df[atr_column_name].iloc[-1]

                print(Fore.WHITE+Style.BRIGHT+f"\nLast ATR ({timeframe}, Period {period}): {Fore.CYAN}{last_atr_value:.4f}")

                plt.clear_figure()
                plt.plot(atr_df[atr_column_name].values)
                plt.title(f'ATR for {symbol} ({timeframe}, Period {period})')
                plt.show()
                print(Fore.CYAN+Style.BRIGHT+"\n---------------------------------------")
            else:
                print(Fore.YELLOW+f"Could not calculate ATR for {symbol} in {timeframe} with period {period}.")

        except ccxt.ExchangeError as e:
            print(Fore.RED+Style.BRIGHT+f"Bybit Err: {e}")
            logging.error(f"Bybit Err: {e}")
        except Exception as e:
            print(Fore.RED+Style.BRIGHT+f"Err disp ATR: {e}")
            logging.error(f"Err disp ATR: {e}")
        finally:
            input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")
            
    def debug_apikeys(self):
        """Displays debug information about API keys (masks secret key)."""
        os.system('clear')
        print(Fore.CYAN + Style.BRIGHT + "╔══════════════DEBUG API KEYS══════════╗")
        print(Fore.CYAN + Style.BRIGHT + "║ " + Fore.RED + "!!! DO NOT SHARE !!!" + Fore.CYAN + " ║")
        print(Fore.CYAN + Style.BRIGHT + "╚══════════════════════════════════╝")
        print(Fore.YELLOW + Style.BRIGHT + "\nAPI Key (BYBIT_API_KEY):")
        print(Fore.GREEN + f"  {CONFIG.api_key if CONFIG.api_key else 'Not Loaded'}")
        print(Fore.YELLOW + Style.BRIGHT + "\nAPI Secret (BYBIT_API_SECRET):")
        print(Fore.GREEN + f"  {'*' * len(CONFIG.api_secret) if CONFIG.api_secret else 'Not Loaded'}")
        input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def place_mkt_order(self):
        """Places a market order based on user input."""
        symbol = input(Fore.YELLOW + "Enter symbol (e.g., BTCUSDT): ").upper()
        side_str = input(Fore.YELLOW + "Buy/Sell: ").lower()
        side = OrderSide(side_str)
        amount = float(input(Fore.YELLOW + "Enter quantity: "))
        confirmation = input(Fore.YELLOW + Style.BRIGHT + f"Confirm {side.value.upper()} MARKET order for {amount} {symbol}? (y/n): ").lower()
        if confirmation == 'y':
            order_details = self.execute_order(OrderType.MARKET, symbol, side, amount)
            if order_details:
                os.system("clear")
                print(Fore.CYAN + Style.BRIGHT + "╔═══════════MARKET ORDER EXECUTED════════════╗")
                print(Fore.WHITE + f"\nSymbol: {Fore.GREEN}{symbol}")
                print(Fore.WHITE + f"Side: {Fore.GREEN if side == OrderSide.BUY else Fore.RED}{side.value.upper()}")
                print(Fore.WHITE + f"Amount: {Fore.GREEN}{amount}")
                if order_details.get("orderId"):
                    print(Fore.WHITE + f"Order ID: {Fore.CYAN}{order_details['orderId']}")
                else:
                    print(Fore.RED + Style.BRIGHT + "Market order executed, but Order ID not available.")
            else:
                print(Fore.RED + Style.BRIGHT + "Market order failed to execute.")
        else:
            print(Fore.YELLOW + "Market order placement aborted by user.")
        input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")

    def place_lmt_order(self):
        """Places a limit order based on user input."""
        symbol = input(Fore.YELLOW + "Symbol (e.g., BTCUSDT): ").upper()
        side_str = input(Fore.YELLOW + "Buy/Sell: ").lower()
        side = OrderSide(side_str)
        amount = float(input(Fore.YELLOW + "Quantity: "))
        price = float(input(Fore.YELLOW + "Enter price: "))
        confirmation = input(Fore.YELLOW + Style.BRIGHT + f"Confirm {side.value.upper()} LIMIT order for {amount} {symbol} at {price}? (y/n): ").lower()
        if confirmation == 'y':
            order_details = self.execute_order(OrderType.LIMIT, symbol, side, amount, price)
            if order_details:
                os.system("clear")
                print(Fore.CYAN + Style.BRIGHT + "╔═══════════LIMIT ORDER PLACED═══════════╗")
                print(Fore.WHITE + f"\nSymbol: {Fore.GREEN}{symbol}")
                print(Fore.WHITE + f"Side: {Fore.GREEN if side == OrderSide.BUY else Fore.RED}{side.value.upper()}")
                print(Fore.WHITE + f"Amount: {Fore.GREEN}{amount}")
                print(Fore.WHITE + f"Price: {Fore.GREEN}{price}")
                if order_details.get("orderId"):
                    print(Fore.WHITE + f"Order ID: {Fore.CYAN}{order_details['orderId']}")
                else:
                    print(Fore.RED + Style.BRIGHT + "Limit order placed, but Order ID not available.")
            else:
                print(Fore.RED + Style.BRIGHT + "Limit order failed to place.")
        else:
            print(Fore.YELLOW + "Limit order placement aborted by user.")
        input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")


from queue import Queue # Correct import for Queue (thread-safe queue)

class RM:
    """Risk Management class."""
    def __init__(self, config_risk):
        """Initializes RiskManager."""
        self.max_risk_per_trade = config_risk['max_per_trade']
        self.max_leverage = config_risk['max_leverage']
        self.daily_loss_limit = config_risk['daily_loss_limit']
        self.leverage = 1

    def set_lev(self, leverage: int):
        """Sets leverage."""
        self.leverage = min(leverage, self.max_leverage)

    def pos_size(self, entry_price: float, stop_loss_price: float, account_balance: float) -> float:
        """Calculates position size."""
        risk_amount = account_balance * self.max_risk_per_trade
        risk_per_contract = abs(entry_price - stop_loss_price)
        if risk_per_contract == 0:
            return 0
        position_size = (risk_amount / risk_per_contract) * self.leverage
        return position_size


class NH:
    """Notification Handler class."""
    def __init__(self, email_config):
        """Initializes NotificationHandler."""
        self.server = email_config['server']
        self.user = email_config['user']
        self.password = email_config['password']
        self.receiver = email_config['receiver']
        self.alert_queue = Queue() # Corrected to use queue.Queue
        threading.Thread(target=self._process_alerts, daemon=True).start()

    def cfg_email(self, smtp_details):
        """Configures email settings."""
        self.server = smtp_details['server']
        self.user = smtp_details['user']
        self.password = smtp_details['password']
        print(Fore.GREEN + "Email settings updated.")

    def send_alert(self, message: str):
        """Sends an alert message to the email queue."""
        self.alert_queue.put(message)

    def price_alert(self, symbol: str, target_price: float):
        """Sets up a price alert."""
        threading.Thread(target=self._price_check_loop, args=(symbol, target_price), daemon=True).start()

    def _price_check_loop(self, symbol, target_price):
        """Price check loop for alerts."""
        while True:
            try:
                exch = ccxt.bybit({'options': {'defaultType': 'swap'}})
                ticker = exch.fetch_ticker(symbol)
                current_price = ticker['last']
                if current_price <= target_price:
                    self.send_alert(f"Price alert: {symbol} reached {target_price}")
                    break
            except Exception as e:
                logging.error(f"Error in price check loop for {symbol}: {e}")
            time.sleep(60)

    def _process_alerts(self):
        """Processes alerts from the queue and sends emails."""
        while True:
            message_text = self.alert_queue.get()
            self._send_email(message_text)
            self.alert_queue.task_done()

    def _send_email(self, message_text):
        """Sends an email alert."""
        if not all([self.server, self.user, self.password, self.receiver]):
            print(Fore.YELLOW + "Email configuration not fully set. Alert not sent to email.")
            return
        try:
            msg = EmailMessage()
            msg.set_content(message_text)
            msg['Subject'] = 'Trading Bot Alert'
            msg['From'] = self.user
            msg['To'] = self.receiver
            with smtplib.SMTP_SSL(self.server, 465) as smtp:
                smtp.login(self.user, self.password)
                smtp.send_message(msg)
            print(Fore.GREEN + "Email alert sent.")
        except smtplib.SMTPException as e:
            print(Fore.RED + f"SMTP error sending email: {e}")
            logging.error(f"SMTP error sending email: {e}")
        except Exception as e:
            print(Fore.RED + f"Error sending email alert: {e}")
            logging.error(f"General error sending email alert: {e}")


class SE:
    """Strategy Engine class."""
    def run_backtest(self, df, strategy_name):
        """Runs backtest for a given strategy."""
        if strategy_name == 'ema':
            return self._ema_strat(df)
        else:
            raise ValueError(f"Strategy '{strategy_name}' is not supported.")

    def _ema_strat(self, df):
        """EMA crossover strategy backtest."""
        df['ema_fast'] = df['close'].ewm(span=12, adjust=False).mean()
        df['ema_slow'] = df['close'].ewm(span=26, adjust=False).mean()
        df['signal'] = np.where(df['ema_fast'] > df['ema_slow'], 1, -1)
        df['position'] = df['signal'].shift(1)
        df['rets'] = df['close'].pct_change()
        df['strat_rets'] = df['position'] * df['rets']
        df['cum_rets'] = (1 + df['strat_rets']).cumprod() - 1
        bt_res = {'tot_ret_perc': df['cum_rets'].iloc[-1] * 100,
                  'max_dd_perc': self._max_dd(df['cum_rets']) * 100,
                  'cum_rets': df['cum_rets']}
        return bt_res

    def _max_dd(self, cumulative_returns):
        """Calculates max drawdown."""
        peak = cumulative_returns.iloc[0]
        max_drawdown = 0
        for ret in cumulative_returns:
            if ret > peak:
                peak = ret
            drawdown = (peak - ret) / peak if peak != 0 else 0
            if drawdown > max_drawdown:
                max_drawdown = drawdown
        return max_drawdown


def get_msentiment():
    """Fetches market sentiment (Fear/Greed Index)."""
    try:
        response = requests.get('https://api.alternative.me/fng/', timeout=10)
        response.raise_for_status()
        data = response.json()
        return data['data'][0]['value']
    except requests.exceptions.RequestException as e:
        error_message = f"Error fetching market sentiment: {str(e)}"
        logging.error(error_message)
        return error_message


if __name__ == "__main__":
    terminal = BTT()
    terminal.main()