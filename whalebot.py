import os
import logging
import requests
import pandas as pd
import numpy as np
from datetime import datetime
import hmac
import hashlib
import time
from dotenv import load_dotenv
from typing import Dict, Tuple, List, Union
from colorama import init, Fore, Style
from zoneinfo import ZoneInfo
from decimal import Decimal, getcontext
import json

# Decimal precision
getcontext().prec = 10

# Colorama initialization
init(autoreset=True)

# Load environment variables
load_dotenv()
API_KEY = os.getenv("BYBIT_API_KEY")
API_SECRET = os.getenv("BYBIT_API_SECRET")
if not API_KEY or not API_SECRET:
    raise ValueError("BYBIT_API_KEY and BYBIT_API_SECRET must be set in .env")
BASE_URL = os.getenv("BYBIT_BASE_URL", "https://api.bybit.com")

# Constants
CONFIG_FILE = "config.json"
LOG_DIRECTORY = "bot_logs"
TIMEZONE = ZoneInfo("America/Chicago")
MAX_API_RETRIES = 3
RETRY_DELAY_SECONDS = 5
VALID_INTERVALS = ["1", "3", "5", "15", "30", "60", "120", "240", "D", "W", "M"]
RETRY_ERROR_CODES = [429, 500, 502, 503, 504]

# Neon Color Scheme
NEON_GREEN = Fore.LIGHTGREEN_EX
NEON_BLUE = Fore.CYAN
NEON_PURPLE = Fore.MAGENTA
NEON_YELLOW = Fore.YELLOW
NEON_RED = Fore.LIGHTRED_EX
RESET = Style.RESET_ALL

# Create log directory
os.makedirs(LOG_DIRECTORY, exist_ok=True)

# --- Configuration Management ---
def load_config(filepath: str) -> dict:
    """Loads configuration from a JSON file, with defaults and validation."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print(f"{NEON_YELLOW}Could not load or parse config. Loading defaults.{RESET}")
        config = {
            "interval": "15",
            "analysis_interval": 30,
            "retry_delay": 5,
            "momentum_period": 10,
            "momentum_ma_short": 12,
            "momentum_ma_long": 26,
            "volume_ma_period": 20,
            "atr_period": 14,
            "trend_strength_threshold": 0.4,
            "sideways_atr_multiplier": 1.5,
            "indicators": {
                "ema_alignment": True,
                "momentum": True,
                "volume_confirmation": True,
                "divergence": True,
                "stoch_rsi": True,
                "rsi": False,
                "macd": False,
            },
            "weight_sets": {
                "low_volatility": {
                    "ema_alignment": 0.4,
                    "momentum": 0.3,
                    "volume_confirmation": 0.2,
                    "divergence": 0.1,
                    "stoch_rsi": 0.7,
                    "rsi": 0.0,
                    "macd": 0.0,
                },
            },
        }
    # Further validation and more complex default settings can be added here
    return config

CONFIG = load_config(CONFIG_FILE)


# --- Logging Setup ---
def setup_logger(symbol: str) -> logging.Logger:
    """Sets up a logger for the given symbol with file and stream handlers."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_filename = os.path.join(LOG_DIRECTORY, f"{symbol}_{timestamp}.log")
    logger = logging.getLogger(symbol)
    logger.setLevel(logging.INFO)

    # File handler
    file_handler = logging.FileHandler(log_filename)
    file_handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"))
    logger.addHandler(file_handler)

    # Stream handler (console output)
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(
        logging.Formatter(NEON_BLUE + "%(asctime)s" + RESET + " - %(levelname)s - %(message)s")
    )
    logger.addHandler(stream_handler)
    return logger


# --- API Interaction Functions ---
def generate_signature(params: dict) -> str:
    """Generates a signature for Bybit API requests."""
    param_str = "&".join(f"{key}={value}" for key, value in sorted(params.items()))
    return hmac.new(API_SECRET.encode(), param_str.encode(), hashlib.sha256).hexdigest()

def fetch_current_price(symbol: str, logger: logging.Logger) -> Union[Decimal, None]:
    """Fetches the current price of a symbol from Bybit."""
    endpoint = "/v5/market/tickers"
    params = {
        "category": "linear",
        "symbol": symbol
    }
    response = bybit_request("GET", endpoint, params, logger)
    
    if not response or response.get("retCode") != 0 or not response.get("result"):
        logger.error(f"{NEON_RED}Failed to fetch ticker data: {response}{RESET}")
        return None
    
    tickers = response["result"].get("list", [])
    for ticker in tickers:
        if ticker.get("symbol") == symbol:
            last_price_str = ticker.get("lastPrice")
            if not last_price_str:
                logger.error(f"{NEON_RED}No lastPrice in ticker data{RESET}")
                return None
            try:
                return Decimal(last_price_str)
            except Exception as e:
                logger.error(f"{NEON_RED}Error parsing last price: {e}{RESET}")
                return None
    
    logger.error(f"{NEON_RED}Symbol {symbol} not found in ticker data{RESET}")
    return None
def safe_json_response(response: requests.Response, logger: logging.Logger = None) -> Union[dict, None]:
    """Safely parse JSON response, logging errors."""
    try:
        return response.json()
    except ValueError:
        if logger:
            logger.error(f"{NEON_RED}Invalid JSON response: {response.text}{RESET}")
        return None


def bybit_request(method: str, endpoint: str, params: dict = None, logger: logging.Logger = None) -> Union[dict, None]:
    """Handles Bybit API requests with retry logic."""
    for retry in range(MAX_API_RETRIES):
        try:
            params = params or {}
            timestamp = str(int(datetime.now(TIMEZONE).timestamp() * 1000))
            signature_params = params.copy()  # Create a copy to avoid modifying original
            signature_params['timestamp'] = timestamp # timestamp must be in signature params
            param_str = "&".join(f"{key}={value}" for key, value in sorted(signature_params.items()))
            signature = hmac.new(API_SECRET.encode(), param_str.encode(), hashlib.sha256).hexdigest()

            headers = {
                "X-BAPI-API-KEY": API_KEY,
                "X-BAPI-TIMESTAMP": timestamp,
                "X-BAPI-SIGN": signature,
                "Content-Type": "application/json" # Explicitly set content type for POST requests
            }
            url = f"{BASE_URL}{endpoint}"

            request_kwargs = {
                'method': method,
                'url': url,
                'headers': headers,
                'timeout': 10
            }

            if method == "GET":
                request_kwargs['params'] = params
            elif method == "POST":
                request_kwargs['json'] = params # Use json for POST data

            response = requests.request(**request_kwargs) # Use kwargs for request

            if response.status_code == 200:
                json_response = safe_json_response(response, logger)
                if json_response:
                    return json_response
                else:
                    if logger:
                        logger.error(f"{NEON_RED}Empty or invalid JSON response: {response.text}{RESET}")
                    return None # Handle empty JSON (or non-JSON but 200 OK)
            elif response.status_code in RETRY_ERROR_CODES:
                if logger:
                    logger.warning(
                        f"{NEON_YELLOW}Rate limited or server error. Retrying {retry + 1}/{MAX_API_RETRIES} after {RETRY_DELAY_SECONDS * (2**retry)} seconds...{RESET}"
                    )
                time.sleep(RETRY_DELAY_SECONDS * (2**retry)) # Exponential backoff
            else:
                if logger:
                    logger.error(
                        f"{NEON_RED}Bybit API error: {response.status_code} - {response.text}{RESET}"
                    )
                return None  # Non-retryable error

        except requests.exceptions.RequestException as e:
            if logger:
                logger.error(f"{NEON_RED}API request failed: {e}{RESET}")
            time.sleep(RETRY_DELAY_SECONDS * (2**retry)) # Retry on request exceptions

    if logger:
        logger.error(f"{NEON_RED}Max retries exceeded for endpoint: {endpoint}{RESET}")
    return None


def fetch_klines(symbol: str, interval: str, limit: int = 200, logger: logging.Logger = None) -> pd.DataFrame:
    """Fetches kline data from Bybit and returns it as a Pandas DataFrame."""
    try:
        endpoint = "/v5/market/kline"
        params = {"symbol": symbol, "interval": interval, "limit": limit, "category": "linear"}
        response = bybit_request("GET", endpoint, params, logger)
        if (
            response
            and response.get("retCode") == 0
            and response.get("result")
            and response["result"].get("list")
        ):
            data = response["result"]["list"]
            columns = ["start_time", "open", "high", "low", "close", "volume"]
            if data and len(data[0]) > 6 and data[0][6]:
                columns.append("turnover")
            df = pd.DataFrame(data, columns=columns)
            df["start_time"] = pd.to_numeric(df["start_time"])
            df["start_time"] = pd.to_datetime(df["start_time"], unit="ms")
            

            for col in ["open", "high", "low", "close", "volume", "turnover"]:
                df[col] = pd.to_numeric(df[col], errors="coerce")
            for col in ["open", "high", "low", "close", "volume", "turnover"]:
                if col not in df.columns:
                    df[col] = np.nan  # Ensure all expected columns are present, fill NaN if missing
            if not {"close", "high", "low", "volume"}.issubset(df.columns):
                if logger:
                    logger.error(f"{NEON_RED}Kline data missing required columns after processing.{RESET}")
                return pd.DataFrame() # Return empty DataFrame if essential data is missing
            return df.astype({c: float for c in columns if c != "start_time"}) # Explicitly set dtypes
        if logger:
            logger.error(f"{NEON_RED}Failed to fetch klines: {response}{RESET}") # Log full response for debugging
        return pd.DataFrame() # Return empty DataFrame on failure
    except (requests.exceptions.RequestException, KeyError, ValueError, TypeError) as e:
        if logger:
            logger.exception(f"{NEON_RED}Error fetching klines: {e}{RESET}") # Log exception with traceback
        return pd.DataFrame() # Return empty DataFrame on exception


# --- TradingAnalyzer Class ---
class TradingAnalyzer:
    """Analyzes trading data and calculates technical indicators."""

    def __init__(self, df: pd.DataFrame, logger: logging.Logger, config: dict, symbol: str, interval: str):
        """Initializes TradingAnalyzer with OHLCV data, logger, and configuration."""
        self.df = df
        self.logger = logger
        self.levels = {}  # Support/Resistance levels
        self.fib_levels = {} # Fibonacci retracement levels
        self.config = config
        self.signal = None # Trading signal (not currently used in output)
        self.weight_sets = config["weight_sets"] # Weight sets for different strategies (not fully implemented)
        self.user_defined_weights = self.weight_sets["low_volatility"] # Default weight set
        self.symbol = symbol
        self.interval = interval

    def calculate_sma(self, window: int) -> pd.Series:
        """Calculates the Simple Moving Average."""
        try:
            return self.df["close"].rolling(window=window).mean()
        except KeyError as e:
            self.logger.error(f"{NEON_RED}Missing 'close' column for SMA calculation: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_momentum(self, period: int = 10) -> pd.Series:
        """Calculates the Momentum indicator."""
        try:
            return ((self.df["close"] - self.df["close"].shift(period)) / self.df["close"].shift(period)) * 100
        except (KeyError, ZeroDivisionError) as e:
            self.logger.error(f"{NEON_RED}Momentum calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_cci(self, window: int = 20, constant: float = 0.015) -> pd.Series:
        """Calculates the Commodity Channel Index (CCI)."""
        try:
            typical_price = (self.df["high"] + self.df["low"] + self.df["close"]) / 3
            sma_typical_price = typical_price.rolling(window=window).mean()
            mean_deviation = typical_price.rolling(window=window).apply(lambda x: np.abs(x - x.mean()).mean(), raw=True)
            cci = (typical_price - sma_typical_price) / (constant * mean_deviation)
            return cci

        except (KeyError, ZeroDivisionError) as e:
            self.logger.error(f"{NEON_RED}CCI calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")
        except Exception as e:
            self.logger.exception(f"{NEON_RED}Unexpected error during CCI calculation: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_williams_r(self, window: int = 14) -> pd.Series:
        """Calculates Williams %R indicator."""
        try:
            highest_high = self.df["high"].rolling(window=window).max()
            lowest_low = self.df["low"].rolling(window=window).min()
            wr = (highest_high - self.df["close"]) / (highest_high - lowest_low) * -100
            return wr
        except KeyError as e:
            self.logger.error(f"{NEON_RED}Williams %R calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_mfi(self, window: int = 14) -> pd.Series:
        """Calculates Money Flow Index (MFI)."""
        try:
            typical_price = (self.df["high"] + self.df["low"] + self.df["close"]) / 3
            raw_money_flow = typical_price * self.df["volume"]

            positive_flow = []
            negative_flow = []
            for i in range(1, len(typical_price)):
                if typical_price[i] > typical_price[i - 1]:
                    positive_flow.append(raw_money_flow[i - 1])
                    negative_flow.append(0)
                elif typical_price[i] < typical_price[i - 1]:
                    negative_flow.append(raw_money_flow[i - 1])
                    positive_flow.append(0)
                else:
                    positive_flow.append(0)
                    negative_flow.append(0)

            positive_mf = pd.Series(positive_flow).rolling(window=window).sum()
            negative_mf = pd.Series(negative_flow).rolling(window=window).sum()

            money_ratio = positive_mf / negative_mf
            mfi = 100 - (100 / (1 + money_ratio))

            return mfi
        except (KeyError, ZeroDivisionError) as e:
            self.logger.error(f"{NEON_RED}MFI calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_fibonacci_retracement(self, high: float, low: float, current_price: float) -> Dict[str, float]:
        """Calculates Fibonacci retracement levels."""
        try:
            diff = high - low
            if diff == 0:
                return {}
            fib_levels = {
                "Fib 23.6%": high - diff * 0.236,
                "Fib 38.2%": high - diff * 0.382,
                "Fib 50.0%": high - diff * 0.5,
                "Fib 61.8%": high - diff * 0.618,
                "Fib 78.6%": high - diff * 0.786,
                "Fib 88.6%": high - diff * 0.886,
                "Fib 94.1%": high - diff * 0.941,
            }
            self.levels = {"Support": {}, "Resistance": {}}
            for label, value in fib_levels.items():
                if value < current_price:
                    self.levels["Support"][label] = value
                elif value > current_price:
                    self.levels["Resistance"][label] = value
            self.fib_levels = fib_levels
            return self.fib_levels
        except ZeroDivisionError:
            self.logger.error(f"{NEON_RED}Fibonacci calculation error: Division by zero.{RESET}")
            return {}
        except Exception as e:
            self.logger.exception(f"{NEON_RED}Fibonacci calculation error: {e}{RESET}")
            return {}

    def calculate_pivot_points(self, high: float, low: float, close: float):
        """Calculates pivot points: Pivot Point, R1, S1, R2, S2, R3, S3."""
        try:
            pivot = (high + low + close) / 3
            r1 = (2 * pivot) - low
            s1 = (2 * pivot) - high
            r2 = pivot + (high - low)
            s2 = pivot - (high - low)
            r3 = high + 2 * (pivot - low)
            s3 = low - 2 * (high - pivot)
            self.levels.update(
                {
                    "pivot": pivot,
                    "r1": r1,
                    "s1": s1,
                    "r2": r2,
                    "s2": s2,
                    "r3": r3,
                    "s3": s3,
                }
            )
        except Exception as e:
            self.logger.exception(f"{NEON_RED}Pivot point calculation error: {e}{RESET}")
            self.levels = {}

    def find_nearest_levels(self, current_price: float, num_levels: int = 5) -> Tuple[List[Tuple[str, float]], List[Tuple[str, float]]]:
        """Finds the nearest support and resistance levels to the current price."""
        try:
            support_levels = []
            resistance_levels = []

            def process_level(label, value):
                if value < current_price:
                    support_levels.append((label, value))
                elif value > current_price:
                    resistance_levels.append((label, value))

            for label, value in self.levels.items():
                if isinstance(value, dict): # Handle Fibonacci levels (nested dict)
                    for sub_label, sub_value in value.items():
                        if isinstance(sub_value, (float, Decimal)):
                            process_level(f"{label} ({sub_label})", sub_value)
                elif isinstance(value, (float, Decimal)): # Handle Pivot Points and other single levels
                    process_level(label, value)

            support_levels = sorted(
                support_levels, key=lambda x: abs(x[1] - current_price), reverse=True
            ) # Sort by distance, reversed for nearest *supports* at the end
            nearest_supports = sorted(support_levels[-num_levels:], key=lambda x: x[1]) # Get nearest few and sort by level value

            resistance_levels = sorted(
                resistance_levels, key=lambda x: abs(x[1] - current_price)
            ) # Sort by distance
            nearest_resistances = sorted(
                resistance_levels[:num_levels], key=lambda x: x[1]
            ) # Get nearest few and sort by level value

            return nearest_supports, nearest_resistances

        except (KeyError, TypeError) as e:
            self.logger.error(f"{NEON_RED}Error finding nearest levels: {e}{RESET}")
            return [], []
        except Exception as e:
            self.logger.exception(f"{NEON_RED}Unexpected error finding nearest levels: {e}{RESET}")
            return [], []

    def calculate_atr(self, window: int = 20) -> pd.Series:
        """Calculates Average True Range (ATR)."""
        try:
            high_low = self.df["high"] - self.df["low"]
            high_close = (self.df["high"] - self.df["close"].shift()).abs()
            low_close = (self.df["low"] - self.df["close"].shift()).abs()
            tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
            atr = tr.rolling(window=window).mean()
            return atr
        except KeyError as e:
            self.logger.error(f"{NEON_RED}ATR calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_rsi(self, window: int = 14) -> pd.Series:
        """Calculates Relative Strength Index (RSI)."""
        try:
            delta = self.df["close"].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
            rs = gain / loss
            rsi = np.where(loss == 0, 100, 100 - (100 / (1 + rs))) # Handle division by zero
            return pd.Series(rsi, index=gain.index) # Keep index aligned

        except ZeroDivisionError:
            self.logger.error(f"{NEON_RED}RSI calculation error: Division by zero (handled). Returning NaN.{RESET}")
            return pd.Series(np.nan, index=self.df.index) # Return NaN to signal error
        except KeyError as e:
            self.logger.error(f"{NEON_RED}RSI calculation error: Missing column - {e}{RESET}")
            return pd.Series(dtype="float64")
        except Exception as e:
            self.logger.exception(f"{NEON_RED}Unexpected error during RSI calculation: {e}{RESET}")
            return pd.Series(dtype="float64")


    def calculate_stoch_rsi(self, rsi_window: int = 14, stoch_window: int = 12,
                             k_window: int = 4, d_window: int = 3) -> pd.DataFrame:
        """Calculates Stochastic RSI."""
        try:
            rsi = self.calculate_rsi(window=rsi_window)
            stoch_rsi = (rsi - rsi.rolling(stoch_window).min()) / (
                           rsi.rolling(stoch_window).max() - rsi.rolling(stoch_window).min())
            k_line = stoch_rsi.rolling(window=k_window).mean()
            d_line = k_line.rolling(window=d_window).mean()
            return pd.DataFrame({"stoch_rsi": stoch_rsi, "k": k_line, "d": d_line})
        except (ZeroDivisionError, KeyError) as e:
            self.logger.error(f"{NEON_RED}Stochastic RSI calculation error: {e}{RESET}")
            return pd.DataFrame()

    def calculate_momentum_ma(self) -> None:
        """Calculates Momentum and its Moving Averages (short and long term)."""
        try:
            self.df["momentum"] = self.df["close"].diff(self.config["momentum_period"])
            self.df["momentum_ma_short"] = self.df["momentum"].rolling(window=self.config["momentum_ma_short"]).mean()
            self.df["momentum_ma_long"] = self.df["momentum"].rolling(window=self.config["momentum_ma_long"]).mean()
            self.df["volume_ma"] = self.df["volume"].rolling(window=self.config["volume_ma_period"]).mean()
        except KeyError as e:
            self.logger.error(f"{NEON_RED}Momentum/MA calculation error: Missing column {e}{RESET}")


    def calculate_macd(self) -> pd.DataFrame:
        """Calculates Moving Average Convergence Divergence (MACD)."""
        try:
            close_prices = self.df["close"]
            ma_short = close_prices.ewm(span=12, adjust=False).mean() # Using typical MACD periods: 12, 26, 9
            ma_long = close_prices.ewm(span=26, adjust=False).mean()
            macd = ma_short - ma_long # MACD line is difference
            signal = macd.ewm(span=9, adjust=False).mean() # Signal line is EMA of MACD
            histogram = macd - signal # Histogram represents divergence
            return pd.DataFrame({"macd": macd, "signal": signal, "histogram": histogram})

        except KeyError:
            self.logger.error(f"{NEON_RED}Missing 'close' column for MACD calculation.{RESET}")
            return pd.DataFrame()

    def detect_macd_divergence(self) -> str | None:
        """Detects MACD bullish or bearish divergence based on histogram."""
        if self.df.empty or len(self.df) < 30: # Need enough data for comparison
            return None
        macd_df = self.calculate_macd()
        if macd_df.empty:
            return None
        prices = self.df["close"]
        macd_histogram = macd_df["histogram"]

        if (prices.iloc[-2] > prices.iloc[-1] and macd_histogram.iloc[-2] < macd_histogram.iloc[-1]):
            return "bullish" # Regular Bullish Divergence: Price makes lower low, MACD Histogram makes higher low.
        elif (prices.iloc[-2] < prices.iloc[-1] and macd_histogram.iloc[-2] > macd_histogram.iloc[-1]):
            return "bearish" # Regular Bearish Divergence: Price makes higher high, MACD Histogram makes lower high.
        return None

    def calculate_ema(self, window: int) -> pd.Series:
        """Calculates Exponential Moving Average (EMA)."""
        try:
            return self.df["close"].ewm(span=window, adjust=False).mean()
        except KeyError as e:
            self.logger.error(f"{NEON_RED}Missing 'close' column for EMA calculation: {e}{RESET}")
            return pd.Series(dtype="float64") # Return empty series

    def determine_trend_momentum(self) -> dict:
        """Determines market trend and momentum strength using momentum MAs and ATR."""
        if self.df.empty or len(self.df) < 26: # Need enough data for MA calculations
            return {"trend": "Insufficient Data", "strength": 0}

        atr = self.calculate_atr() # Average True Range for volatility normalization
        if atr.iloc[-1] == 0: # Avoid division by zero in trend strength calculation
            self.logger.warning(f"{NEON_YELLOW}ATR is zero, cannot calculate trend strength.{RESET}")
            return {"trend": "Neutral", "strength": 0}

        self.calculate_momentum_ma() # Calculate momentum MAs first
        if self.df["momentum_ma_short"].iloc[-1] > self.df["momentum_ma_long"].iloc[-1]:
            trend = "Uptrend" # Short-term momentum MA above long-term suggests uptrend
        elif self.df["momentum_ma_short"].iloc[-1] < self.df["momentum_ma_long"].iloc[-1]:
            trend = "Downtrend" # Short-term momentum MA below long-term suggests downtrend
        else:
            trend = "Neutral" # MAs close or equal, trend is neutral

        # Trend strength as normalized difference between momentum MAs by volatility (ATR)
        trend_strength = abs(self.df["momentum_ma_short"].iloc[-1] - self.df["momentum_ma_long"].iloc[-1]) / atr.iloc[-1]
        return {"trend": trend, "strength": trend_strength}


    def calculate_adx(self, window: int = 14) -> float:
        """Calculates Average Directional Index (ADX) to measure trend strength."""
        try:
            df = self.df.copy() # Avoid modifying the original DataFrame

            # True Range calculation
            df["TR"] = pd.concat([df["high"] - df["low"],
                                  abs(df["high"] - df["close"].shift()),
                                  abs(df["low"] - df["close"].shift())], axis=1).max(axis=1)

            # Directional Movement (+DM and -DM)
            df["+DM"] = np.where((df["high"] - df["high"].shift()) > (df["low"].shift() - df["low"]),
                                 np.maximum(df["high"] - df["high"].shift(), 0), 0) # +DM when current high > previous high AND higher than down move
            df["-DM"] = np.where((df["low"].shift() - df["low"]) > (df["high"] - df["high"].shift()),
                                 np.maximum(df["low"].shift() - df["low"], 0), 0) # -DM when previous low < current low AND higher than up move

            # Smoothed True Range and Directional Movements (using rolling sum as approximation of Wilder's method for simplicity)
            df["TR"] = df["TR"].rolling(window).sum()
            df["+DM"] = df["+DM"].rolling(window).sum()
            df["-DM"] = df["-DM"].rolling(window).sum()

            # Directional Indicators (+DI and -DI)
            df["+DI"] = 100 * (df["+DM"] / df["TR"]) # Percentage of +DM relative to TR
            df["-DI"] = 100 * (df["-DM"] / df["TR"]) # Percentage of -DM relative to TR

            # Directional Index (DX) - Measures trend direction strength without considering direction
            df["DX"] = 100 * (abs(df["+DI"] - df["-DI"]) / (df["+DI"] + df["-DI"]))

            # Average Directional Index (ADX) - Smoothed/averaged DX, final ADX value
            adx = df["DX"].rolling(window).mean().iloc[-1] # ADX is MA of DX

            return adx

        except (KeyError, ZeroDivisionError) as e:
            self.logger.error(f"{NEON_RED}ADX calculation error: {e}{RESET}")
            return 0.0 # Return 0 on error to avoid issues down stream
        except Exception as e:
            self.logger.exception(f"{NEON_RED}Unexpected ADX calculation error: {e}{RESET}")
            return 0.0

    def calculate_obv(self) -> pd.Series:
        """Calculates On Balance Volume (OBV) - volume flow indicator."""
        try:
            obv = np.where(self.df["close"] > self.df["close"].shift(1),
                           self.df["volume"], # Volume added on up days
                           np.where(self.df["close"] < self.df["close"].shift(1),
                                    -self.df["volume"], # Volume subtracted on down days
                                    0)) # No volume change on neutral days
            return pd.Series(np.cumsum(obv), index=self.df.index) # Cumulative sum of daily OBV changes
        except KeyError as e:
            self.logger.error(f"{NEON_RED}OBV calculation error: Missing column {e}{RESET}")
            return pd.Series(dtype="float64") # Return empty series in case of error

    def calculate_adi(self) -> pd.Series:
        """Calculates Accumulation/Distribution Index (ADI) - price and volume indicator."""
        try:
            money_flow_multiplier = ((self.df["close"] - self.df["low"]) - (self.df["high"] - self.df["close"])) / (self.df["high"] - self.df["low"])
            money_flow_volume = money_flow_multiplier * self.df["volume"] # Money flow volume for each period
            return money_flow_volume.cumsum() # Cumulative sum represents ADI
        except (KeyError, ZeroDivisionError) as e:
            self.logger.error(f"{NEON_RED}ADI calculation error: {e}{RESET}")
            return pd.Series(dtype="float64") # Return empty series if error

    def calculate_psar(self, acceleration=0.02, max_acceleration=0.2) -> pd.Series:
        """Calculates Parabolic SAR (PSAR) - trend following indicator."""
        psar = pd.Series(index=self.df.index, dtype="float64") # Initialize PSAR series
        psar.iloc[0] = self.df["low"].iloc[0]  # Initialize first PSAR point to first low

        trend = 1      # Initial trend is uptrend (1), downtrend (-1)
        ep = self.df["high"].iloc[0] # Extreme point, highest high in uptrend, lowest low downtrend
        af = acceleration  # Acceleration factor, increases with each new EP

        for i in range(1, len(self.df)):
            if trend == 1: # Uptrend
                psar.iloc[i] = psar.iloc[i-1] + af * (ep - psar.iloc[i-1]) # PSAR calculation
                if self.df["high"].iloc[i] > ep: # If new high is higher than EP, extend EP
                    ep = self.df["high"].iloc[i]
                    af = min(af + acceleration, max_acceleration) # Increase AF, but limit to max_acceleration
                if self.df["low"].iloc[i] < psar.iloc[i]: # Trend reversal condition
                    trend = -1 # Switch to downtrend
                    psar.iloc[i] = ep # New PSAR is previous EP
                    ep = self.df["low"].iloc[i] # New EP is current low
                    af = acceleration # Reset AF

            elif trend == -1: # Downtrend
                psar.iloc[i] = psar.iloc[i-1] + af * (ep - psar.iloc[i-1])
                if self.df["low"].iloc[i] < ep: # If new low is lower than EP, extend EP
                    ep = self.df["low"].iloc[i]
                    af = min(af + acceleration, max_acceleration)
                if self.df["high"].iloc[i] > psar.iloc[i]: # Trend reversal condition
                    trend = 1 # Switch to uptrend
                    psar.iloc[i] = ep # New PSAR is previous EP
                    ep = self.df["high"].iloc[i] # New EP is current high
                    af = acceleration # Reset AF

        return psar


    def calculate_fve(self) -> pd.Series:
        """Calculates Force Volume Element (FVE) - price, volume, and momentum indicator."""
        try:
            force = self.df["close"].diff() * self.df["volume"] # Price change * volume = force
            return force.cumsum() # Cumulative sum for FVE value
        except KeyError as e:
            self.logger.error(f"{NEON_RED}FVE calculation error: {e}{RESET}")
            return pd.Series(dtype="float64") # Return empty Series on error


    def analyze(self, current_price: Decimal, timestamp: str):
        """Analyzes market data, calculates indicators, and prints output."""
        high = self.df["high"].max()
        low = self.df["low"].min()
        close = self.df["close"].iloc[-1]

        self.calculate_fibonacci_retracement(high, low, float(current_price))
        self.calculate_pivot_points(high, low, close)
        nearest_supports, nearest_resistances = self.find_nearest_levels(float(current_price))

        trend_data = self.determine_trend_momentum()
        trend = trend_data.get("trend", "Unknown")
        strength = trend_data.get("strength", 0)
        atr = self.calculate_atr()


        # --- Indicator calculations ---
        obv = self.calculate_obv()
        rsi = self.calculate_rsi()
        mfi = self.calculate_mfi()
        cci = self.calculate_cci()
        wr = self.calculate_williams_r()
        adx = self.calculate_adx()
        adi = self.calculate_adi()
        sma = self.calculate_sma(10)
        psar = self.calculate_psar()
        fve = self.calculate_fve()
        macd_df = self.calculate_macd()


        # --- Prepare indicator values for output ---
        indicator_values = {
            "obv": obv.tail(3).tolist(),
            "rsi": rsi.tail(3).tolist(),
            "mfi": mfi.tail(3).tolist(),
            "cci": cci.tail(3).tolist(),
            "wr": wr.tail(3).tolist(),
            "adx": [adx] * 3, # ADX is single value, repeat for consistent processing in output
            "adi": adi.tail(3).tolist(),
            "mom": [trend_data] * 3, # Trend data (trend string and strength)
            "sma": [self.df["close"].iloc[-1]], # Special handling for SMA—just last value
            "psar": psar.tail(3).tolist(),
            "fve": fve.tail(3).tolist(),
            "macd": macd_df.tail(3).values.tolist() if not macd_df.empty else [], # Handle empty MACD DataFrame
        }

        # --- Construct output string ---
        output = f"""
{NEON_BLUE}Exchange:{RESET} Bybit
{NEON_BLUE}Symbol:{RESET} {self.symbol}
{NEON_BLUE}Interval:{RESET} {self.interval}
{NEON_BLUE}Timestamp:{RESET} {timestamp}
{NEON_BLUE}Price:{RESET}   {self.df['close'].iloc[-3]:.2f} | {self.df['close'].iloc[-2]:.2f} | {self.df['close'].iloc[-1]:.2f}
{NEON_BLUE}Vol:{RESET}   {self.df['volume'].iloc[-3]:,} | {self.df['volume'].iloc[-2]:,} | {self.df['volume'].iloc[-1]:,}
{NEON_BLUE}Current Price:{RESET} {current_price:.2f}
{NEON_BLUE}ATR:{RESET} {atr.iloc[-1]:.4f}
{NEON_BLUE}Trend:{RESET} {trend} (Strength: {strength:.2f})

"""
        # --- Append interpreted indicator outputs ---
        for indicator_name, values in indicator_values.items(): # Process each indicator for output
            output += interpret_indicator(self.logger, indicator_name, values) + "\n"

        output += f"""
{NEON_BLUE}Support and Resistance Levels:{RESET}
"""
        for s in nearest_supports:
            output += f"S: {s[0]} ${s[1]:.3f}\n" # Include level label in output
        for r in nearest_resistances:
            output += f"R: {r[0]} ${r[1]:.3f}\n" # Include level label

        print(output) # Print formatted output to console


# --- Indicator Interpretation Function ---
def interpret_indicator(logger: logging.Logger, indicator_name: str, values: List[float]) -> Union[str, None]:
    """Interprets indicator values and returns a human-readable string for output."""
    if values is None or not values: # Check for empty values to avoid errors
        return f"{indicator_name.upper()}: No data or calculation error."

    try:
        if indicator_name == "rsi":
            if values[-1] > 70:
                return f"{NEON_RED}RSI:{RESET} Overbought ({values[-1]:.2f})"
            elif values[-1] < 30:
                return f"{NEON_GREEN}RSI:{RESET} Oversold ({values[-1]:.2f})"
            else:
                return f"{NEON_YELLOW}RSI:{RESET} Neutral ({values[-1]:.2f})"
        elif indicator_name == "mfi":
            if values[-1] > 80:
                return f"{NEON_RED}MFI:{RESET} Overbought ({values[-1]:.2f})"
            elif values[-1] < 20:
                return f"{NEON_GREEN}MFI:{RESET} Oversold ({values[-1]:.2f})"
            else:
                return f"{NEON_YELLOW}MFI:{RESET} Neutral ({values[-1]:.2f})"
        elif indicator_name == "cci":
            if values[-1] > 100:
                return f"{NEON_RED}CCI:{RESET} Overbought ({values[-1]:.2f})"
            elif values[-1] < -100:
                return f"{NEON_GREEN}CCI:{RESET} Oversold ({values[-1]:.2f})"
            else:
                return f"{NEON_YELLOW}CCI:{RESET} Neutral ({values[-1]:.2f})"
        elif indicator_name == "wr":
            if values[-1] < -80:
                return f"{NEON_GREEN}Williams %R:{RESET} Oversold ({values[-1]:.2f})"
            elif values[-1] > -20:
                return f"{NEON_RED}Williams %R:{RESET} Overbought ({values[-1]:.2f})"
            else:
                return f"{NEON_YELLOW}Williams %R:{RESET} Neutral ({values[-1]:.2f})"
        elif indicator_name == "adx":
            if values[0] > 25: # ADX > 25 usually indicates trending market
                return f"{NEON_GREEN}ADX:{RESET} Trending ({values[0]:.2f})"
            else:
                return f"{NEON_YELLOW}ADX:{RESET} Ranging ({values[0]:.2f})"
        elif indicator_name == "obv": # On Balance Volume interpretation
            return f"{NEON_BLUE}OBV:{RESET} {'Bullish' if values[-1] > values[-2] else 'Bearish' if values[-1] < values[-2] else 'Neutral'}"
        elif indicator_name == "adi": # Accumulation/Distribution Index
            return f"{NEON_BLUE}ADI:{RESET} {'Accumulation' if values[-1] > values[-2] else 'Distribution' if values[-1] < values[-2] else 'Neutral'}"
        elif indicator_name == "mom": # Momentum trend interpretation
            trend = values[0]["trend"]
            strength = values[0]["strength"]
            return f"{NEON_PURPLE}Momentum:{RESET} {trend} (Strength: {strength:.2f})"
        elif indicator_name == "sma": # Simple Moving Average—simple price level display
            return f"{NEON_YELLOW}SMA (10):{RESET} {values[0]:.2f}"
        elif indicator_name == "psar": # Parabolic SAR—basic display, more complex interpretation needed for signals
            return f"{NEON_BLUE}PSAR:{RESET} {values[-1]:.4f} (Last Value)"  # Changed NEON_CYAN to NEON_BLUE
            
        elif indicator_name == "fve": # Force Volume Element, trend and momentum
            return f"{NEON_BLUE}FVE:{RESET} {values[-1]:.0f} (Last Value)" # Last FVE
        elif indicator_name == "macd": # MACD interpretation - complex, showing MACD value for now
            macd_values = values[-1] # Get last MACD values (last row of DataFrame tail)
            if len(macd_values) == 3:
                macd_line, signal_line, histogram = macd_values[0], macd_values[1], macd_values[2]
                return (f"{NEON_GREEN}MACD:{RESET} MACD={macd_line:.2f}, Signal={signal_line:.2f}, Histogram={histogram:.2f}")
            else:
                return f"{NEON_RED}MACD:{RESET} Calculation issue." # Indicate if MACD data is not as expecte

        else:
            return None # For unrecognized indicator names

    except (TypeError, IndexError) as e:
        logger.error(f"Error interpreting {indicator_name}: {e}") # Log interpretation errors
        return f"{indicator_name.upper()}: Interpretation error." # Indicate error in console output
    except Exception as e:
        logger.error(f"Unexpected error interpreting {indicator_name}: {e}")
        return f"{indicator_name.upper()}: Unexpected error."


# --- Main execution ---
def main():
    """Main function to run the trading analysis bot."""
    symbol = ""
    while True: # Input loop for trading symbol
        symbol = input(f"{NEON_BLUE}Enter trading symbol (e.g., BTCUSDT): {RESET}").upper().strip()
        if symbol:
            break # Exit loop if symbol is entered
        print(f"{NEON_RED}Symbol cannot be empty.{RESET}")

    interval = ""
    while True: # Input loop for timeframe interval
        interval = input(f"{NEON_BLUE}Enter timeframe (e.g., {', '.join(VALID_INTERVALS)}): {RESET}").strip()
        if not interval:
            interval = CONFIG["interval"] # Use default interval from config
            print(f"{NEON_YELLOW}No interval provided. Using default of {interval}{RESET}")
            break # Exit loop using default
        if interval in VALID_INTERVALS: # Validate interval against valid list
            break # Exit loop if interval is valid
        print(f"{NEON_RED}Invalid interval: {interval}{RESET}")

    logger = setup_logger(symbol) # Set up logging for this symbol
    analysis_interval = CONFIG["analysis_interval"] # Get analysis interval from config
    retry_delay = CONFIG["retry_delay"] # Get retry delay from config


    while True: # Main analysis loop - runs continuously

        try:
            current_price = fetch_current_price(symbol, logger) # Fetch real-time price
            if current_price is None: # Handle price fetch failure
                logger.error(f"{NEON_RED}Failed to fetch current price. Retrying in {retry_delay} seconds...{RESET}")
                time.sleep(retry_delay)
                continue # Retry price fetch

            df = fetch_klines(symbol, interval, logger=logger) # Fetch kline data (OHLCV)
            if df.empty: # Handle kline data fetch failure
                logger.error(f"{NEON_RED}Failed to fetch kline data. Retrying in {retry_delay} seconds...{RESET}")
                time.sleep(retry_delay)
                continue # Retry kline fetch

            analyzer = TradingAnalyzer(df, logger, CONFIG, symbol, interval) # Initialize analyzer with data
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S") # Get current timestamp
            analyzer.analyze(current_price, timestamp) # Perform analysis and output

            time.sleep(analysis_interval) # Pause for specified analysis interval

        except requests.exceptions.RequestException as e: # Network request errors
            logger.error(f"{NEON_RED}Network error: {e}. Retrying in {retry_delay} seconds...{RESET}")
            time.sleep(retry_delay) # Wait before retrying
        except KeyboardInterrupt: # User initiated stop signal (Ctrl+C)
            logger.info(f"{NEON_YELLOW}Analysis stopped by user.{RESET}")
            break # Exit main loop and program
        except Exception as e: # Catch any other unexpected errors
            logger.exception(f"{NEON_RED}An unexpected error occurred: {e}. Retrying in {retry_delay} seconds...{RESET}")
            time.sleep(retry_delay) # Wait and retry


if __name__ == "__main__":
    main() # Execute main function when script is run
