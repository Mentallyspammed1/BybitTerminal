from colorama import init, Fore, Style
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
from typing import Dict, Tuple, List, Union, Optional
from zoneinfo import ZoneInfo
from decimal import Decimal, getcontext
import json
from logging.handlers import RotatingFileHandler
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import ccxt

# Neon Color Scheme
NEON_GREEN = Fore.LIGHTGREEN_EX
NEON_BLUE = Fore.CYAN
NEON_PURPLE = Fore.MAGENTA
NEON_YELLOW = Fore.YELLOW
NEON_RED = Fore.LIGHTRED_EX
NEON_CYAN = Fore.CYAN
RESET = Style.RESET_ALL

# Initialize Colorama
init(autoreset=True)

# Load environment variables
load_dotenv()

# Set Decimal Precision
getcontext().prec = 10

# API Keys from Environment Variables
API_KEY = os.getenv("BYBIT_API_KEY")
API_SECRET = os.getenv("BYBIT_API_SECRET")

# Check for API keys
if not API_KEY or not API_SECRET:
    raise ValueError("BYBIT_API_KEY and BYBIT_API_SECRET must be set in .env")

# Base URL for Bybit API
BASE_URL = os.getenv("BYBIT_BASE_URL", "https://api.bybit.com")

# Configuration File and Log Directory
CONFIG_FILE = "config.json"
LOG_DIRECTORY = "bot_logs"

# Timezone for timestamps
TIMEZONE = ZoneInfo("America/Chicago")

# API Retry Settings
MAX_API_RETRIES = 3
RETRY_DELAY_SECONDS = 5

# Valid Intervals for Kline Data
VALID_INTERVALS = ["1m", "3m", "5m", "15m", "30m", "60m", "120m", "240m", "1D", "1W", "1M"]

# HTTP Retry Error Codes
RETRY_ERROR_CODES = [429, 500, 502, 503, 504]

# Ensure Log Directory Exists
os.makedirs(LOG_DIRECTORY, exist_ok=True)


class SensitiveFormatter(logging.Formatter):
    """Formatter to mask sensitive data in logs."""
    def format(self, record):
        msg = super().format(record)
        return msg.replace(API_KEY, "***").replace(API_SECRET, "***")


def load_config(filepath: str) -> dict:
    """Loads configuration from JSON file or defaults."""
    default_config = {
        "symbol": "BTCUSDT",
        "interval": "1m",
        "analysis_interval": 5,
        "retry_delay": 5,
        "momentum_period": 7,
        "momentum_ma_short": 9,
        "momentum_ma_long": 21,
        "volume_ma_period": 15,
        "atr_period": 10,
        "trend_strength_threshold": 0.3,
        "sideways_atr_multiplier": 1.2,
        "indicators": {
            "ema_alignment": True,
            "momentum": True,
            "volume_confirmation": True,
            "divergence": False,
            "stoch_rsi": True,
            "rsi": True,
            "macd": False,
            "bollinger_bands": True,
            "vwap": True,
            "obv": False,
            "adi": False,
            "cci": True,
            "wr": True,
            "adx": False,
            "psar": True,
            "sma_10": True
        },
        "weight_sets": {
            "scalping": {
                "ema_alignment": 0.2,
                "momentum": 0.3,
                "volume_confirmation": 0.2,
                "stoch_rsi": 0.6,
                "rsi": 0.2,
                "bollinger_bands": 0.3,
                "vwap": 0.4,
                "cci": 0.3,
                "wr": 0.3,
                "psar": 0.2,
                "sma_10": 0.1
            }
        },
        "rsi_period": 10,
        "bollinger_bands_period": 15,
        "bollinger_bands_std_dev": 1.5,
        "orderbook_limit": 50,
        "orderbook_cluster_threshold": 500,
        "signal_score_threshold": 1.2,
        "stoch_rsi_oversold_threshold": 25,
        "stoch_rsi_overbought_threshold": 75,
        "stoch_rsi_confidence_boost": 7,
        "rsi_confidence_boost": 3,
        "mfi_confidence_boost": 3,
        "order_book_support_confidence_boost": 5,
        "order_book_resistance_confidence_boost": 5,
        "stop_loss_multiple": 2.0,
        "take_profit_multiple": 0.8,
        "order_book_wall_threshold_multiplier": 3,
        "order_book_depth_to_check": 20,
        "price_change_threshold": 0.003,
        "atr_change_threshold": 0.003,
        "signal_cooldown_s": 30,
        "order_book_debounce_s": 0.5,
        "ema_short_period": 9,
        "ema_long_period": 21,
        "volume_confirmation_multiplier": 2.0,
        "scalping_signal_threshold": 3,
        "account_risk_percent": 0.01  # Default account risk per trade
    }

    if not os.path.exists(filepath):
        with open(filepath, 'w') as f:
            json.dump(default_config, f, indent=4)
        print(f"{NEON_YELLOW}Created new config file with defaults for scalping{RESET}")
        return default_config

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            config = json.load(f)
            if "weight_sets" not in config:
                config["weight_sets"] = default_config["weight_sets"]
            return config
    except (FileNotFoundError, json.JSONDecodeError):
        print(f"{NEON_YELLOW}Could not load or parse config. Loading defaults for scalping.{RESET}")
        return default_config

CONFIG = load_config(CONFIG_FILE)


def create_session() -> requests.Session:
    """Creates a session with retry mechanism for API requests."""
    session = requests.Session()
    retries = Retry(
        total=MAX_API_RETRIES,
        backoff_factor=0.5,
        status_forcelist=RETRY_ERROR_CODES,
        allowed_methods=["GET", "POST"]
    )
    session.mount('https://', HTTPAdapter(max_retries=retries))
    return session


def setup_logger(symbol: str) -> logging.Logger:
    """Sets up a logger for the given symbol."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_filename = os.path.join(LOG_DIRECTORY, f"{symbol}_{timestamp}.log")
    logger = logging.getLogger(symbol)
    logger.setLevel(logging.INFO)

    file_handler = RotatingFileHandler(
        log_filename,
        maxBytes=10 * 1024 * 1024,
        backupCount=5
    )
    file_handler.setFormatter(SensitiveFormatter("%(asctime)s - %(levelname)s - %(message)s"))
    logger.addHandler(file_handler)

    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(SensitiveFormatter(NEON_BLUE + "%(asctime)s" + RESET + " - %(levelname)s - %(message)s"))
    logger.addHandler(stream_handler)

    return logger


def bybit_request(method: str, endpoint: str, params: Optional[dict] = None, logger: Optional[logging.Logger] = None) -> Optional[dict]:
    """Sends a signed request to Bybit API with retries."""
    session = create_session()
    try:
        params = params or {}
        timestamp = str(int(datetime.now(TIMEZONE).timestamp() * 1000))
        signature_params = params.copy()
        signature_params['timestamp'] = timestamp
        param_str = "&".join(f"{key}={value}" for key, value in sorted(signature_params.items()))
        signature = hmac.new(API_SECRET.encode(), param_str.encode(), hashlib.sha256).hexdigest()
        headers = {
            "X-BAPI-API-KEY": API_KEY,
            "X-BAPI-TIMESTAMP": timestamp,
            "X-BAPI-SIGN": signature,
            "Content-Type": "application/json"
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
            request_kwargs['json'] = params

        response = session.request(**request_kwargs)
        response.raise_for_status()
        json_response = response.json()
        if json_response and json_response.get("retCode") == 0:
            return json_response
        else:
            if logger:
                logger.error(f"{NEON_RED}Bybit API error: {json_response.get('retCode')} - {json_response.get('retMsg')}{RESET}")
            return None

    except requests.exceptions.RequestException as e:
        if logger:
            logger.error(f"{NEON_RED}API request failed: {e}{RESET}")
        return None


def fetch_current_price(symbol: str, logger: logging.Logger) -> Union[Decimal, None]:
    """Fetches the current price for a given symbol."""
    endpoint = "/v5/market/tickers"
    params = {"category": "linear", "symbol": symbol}
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


def fetch_klines(symbol: str, interval: str, limit: int = 200, logger: logging.Logger = None) -> pd.DataFrame:
    """Fetches kline data for a symbol and interval."""
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
                    df[col] = np.nan
            if not {"close", "high", "low", "volume"}.issubset(df.columns):
                if logger:
                    logger.error(f"{NEON_RED}Kline data missing required columns after processing.{RESET}")
                return pd.DataFrame()

            return df.astype({c: float for c in columns if c != "start_time"})

        if logger:
            logger.error(f"{NEON_RED}Failed to fetch klines: {response}{RESET}")
        return pd.DataFrame()
    except (requests.exceptions.RequestException, KeyError, ValueError, TypeError) as e:
        if logger:
            logger.exception(f"{NEON_RED}Error fetching klines: {e}{RESET}")
        return pd.DataFrame()


def fetch_orderbook(symbol: str, limit: int, logger: logging.Logger) -> Optional[dict]:
    """Fetches orderbook data for a symbol using ccxt."""
    retry_count = 0
    exchange = ccxt.bybit()
    while retry_count <= MAX_API_RETRIES:
        try:
            orderbook_data = exchange.fetch_order_book(symbol, limit=limit)
            if orderbook_data:
                return orderbook_data
            else:
                logger.error(f"{NEON_RED}Failed to fetch orderbook data from ccxt (empty response). Retrying in {RETRY_DELAY_SECONDS} seconds...{RESET}")
                time.sleep(RETRY_DELAY_SECONDS)
                retry_count += 1
        except ccxt.ExchangeError as e:
            if "orderbook_limit" in str(e).lower():
                logger.warning(f"{NEON_YELLOW}ccxt ExchangeError: orderbook_limit issue. Retrying in {RETRY_DELAY_SECONDS} seconds...{RESET}")
            else:
                logger.error(f"{NEON_RED}ccxt ExchangeError fetching orderbook: {e}. Retrying in {RETRY_DELAY_SECONDS} seconds...{RESET}")
            time.sleep(RETRY_DELAY_SECONDS)
            retry_count += 1
        except ccxt.NetworkError as e:
            logger.error(f"{NEON_RED}ccxt NetworkError fetching orderbook: {e}. Retrying in {RETRY_DELAY_SECONDS} seconds...{RESET}")
            time.sleep(RETRY_DELAY_SECONDS)
            retry_count += 1
        except Exception as e:
            logger.exception(f"{NEON_RED}Unexpected error fetching orderbook with ccxt: {e}. Retrying in {RETRY_DELAY_SECONDS} seconds...{RESET}")
            time.sleep(RETRY_DELAY_SECONDS)
            retry_count += 1

    logger.error(f"{NEON_RED}Max retries reached for orderbook fetch using ccxt. Aborting.{RESET}")
    return None


def get_account_balance(api_key: str, api_secret: str, logger: logging.Logger) -> Optional[Decimal]:
    """Fetches account balance from Bybit."""
    exchange = ccxt.bybit({
        'apiKey': api_key,
        'secret': api_secret,
        'options': {'defaultType': 'spot'}
    })
    try:
        balance = exchange.fetch_balance()
        return balance['USDT']['total']
    except ccxt.ExchangeError as e:
        logger.error(f"{NEON_RED}CCXT ExchangeError fetching balance: {e}{RESET}")
        return None
    except ccxt.NetworkError as e:
        logger.error(f"{NEON_RED}CCXT NetworkError fetching balance: {e}{RESET}")
        return None
    except Exception as e:
        logger.error(f"{NEON_RED}Unexpected error fetching balance with CCXT: {e}{RESET}")
        return None


def calculate_position_size(account_balance: Decimal, atr_value: float, price_change_threshold: float, account_risk_percent: float, current_price_decimal: Decimal) -> Decimal:
    """Calculates position size based on account balance and risk parameters."""
    if not atr_value or atr_value == 0:
        return Decimal('0')

    risk_amount = account_balance * Decimal(str(account_risk_percent))
    stop_loss_distance = Decimal(str(price_change_threshold * atr_value))
    if stop_loss_distance == 0:
        return Decimal('0')

    position_size = risk_amount / stop_loss_distance
    position_size_contracts = position_size / current_price_decimal

    # Consider adjusting contract size based on minimum trade sizes and contract details for the exchange
    return position_size_contracts.quantize(Decimal('0.001')) # Example quantization


def analyze_orderbook_imbalance(orderbook_data: dict, price_change_threshold: float, order_book_wall_threshold_multiplier: float, order_book_depth_to_check: int, current_price: Decimal, logger: logging.Logger) -> float:
    """Analyzes order book imbalance for signal confirmation."""
    try:
        bids = orderbook_data['bids'][:order_book_depth_to_check]
        asks = orderbook_data['asks'][:order_book_depth_to_check]

        total_bid_size = sum(bid[1] for bid in bids)
        total_ask_size = sum(ask[1] for ask in asks)

        if total_bid_size + total_ask_size == 0:
            return 0

        imbalance_score = (total_bid_size - total_ask_size) / (total_bid_size + total_ask_size)
        return imbalance_score

    except (KeyError, TypeError) as e:
        logger.error(f"{NEON_RED}Error analyzing order book imbalance: {e}{RESET}")
        return 0


def confirm_signal_with_orderbook(signal, current_price, orderbook_data, config: dict, logger: logging.Logger) -> str:
    """Confirms or rejects a signal based on orderbook conditions."""
    order_book_wall_threshold_multiplier = config['order_book_wall_threshold_multiplier']
    order_book_depth_to_check = config['order_book_depth_to_check']
    bids = orderbook_data['bids'][:order_book_depth_to_check]
    asks = orderbook_data['asks'][:order_book_depth_to_check]

    # Check for resistance wall for SELL signals
    resistance_level = current_price * (1 + 0.001)
    total_ask_size = sum(ask[1] for ask in asks if ask[0] <= resistance_level)

    # Check for support wall for BUY signals
    support_level = current_price * (1 - 0.001)
    total_bid_size = sum(bid[1] for bid in bids if bid[0] >= support_level)

    if signal == "SELL" and total_ask_size < bids[0][1] * order_book_wall_threshold_multiplier:
        logger.info(f"{NEON_YELLOW}Orderbook does not strongly confirm SELL signal, holding{RESET}")
        return "HOLD"
    elif signal == "BUY" and total_bid_size < asks[0][1] * order_book_wall_threshold_multiplier:
        logger.info(f"{NEON_YELLOW}Orderbook does not strongly confirm BUY signal, holding{RESET}")
        return "HOLD"
    return signal


class TradingAnalyzer:
    """Analyzes trading data and generates scalping signals."""

    def __init__(self, df: pd.DataFrame, logger: logging.Logger, config: dict, symbol: str, interval: str):
        """Initializes TradingAnalyzer with OHLCV data, logger, and configuration."""
        self.df = df
        self.logger = logger
        self.levels = {}
        self.fib_levels = {}
        self.config = config
        self.signal = None
        self.weight_sets = config["weight_sets"]
        self.user_defined_weights = self.weight_sets["scalping"]
        self.symbol = symbol
        self.interval = interval
        self.indicator_values = {}
        self.scalping_signals = {"BUY": 0, "SELL": 0}

    def calculate_sma(self, window: int) -> pd.Series:
        """Calculates Simple Moving Average (SMA)."""
        try:
            sma_values = self.df["close"].rolling(window=window).mean()
            self.indicator_values[f"SMA{window}"] = sma_values.iloc[-1]
            return sma_values
        except KeyError as e:
            self.logger.error(f"{NEON_RED}Missing 'close' column for SMA calculation: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_ema_alignment(self) -> float:
        """Calculates EMA alignment score."""
        ema_short = self.calculate_ema(self.config["ema_short_period"])
        ema_long = self.calculate_ema(self.config["ema_long_period"])
        if ema_short.empty or ema_long.empty:
            return 0.0

        latest_short_ema = ema_short.iloc[-1]
        latest_long_ema = ema_long.iloc[-1]
        current_price = self.df["close"].iloc[-1]

        self.indicator_values["EMA_short"] = latest_short_ema
        self.indicator_values["EMA_long"] = latest_long_ema

        if latest_short_ema > latest_long_ema and current_price > latest_short_ema:
            return 1.0
        elif latest_short_ema < latest_long_ema and current_price < latest_short_ema:
            return -1.0
        return 0.0

    def calculate_momentum(self) -> pd.Series:
        """Calculates Momentum."""
        momentum_values = self._calculate_momentum(period=self.config["momentum_period"])
        if not momentum_values.empty:
            self.indicator_values["Momentum"] = momentum_values.iloc[-1]
        return momentum_values

    def _calculate_momentum(self, period: int = 10) -> pd.Series:
        """Internal Momentum calculation function."""
        try:
            return ((self.df["close"] - self.df["close"].shift(period)) / self.df["close"].shift(period)) * 100
        except (KeyError, ZeroDivisionError) as e:
            self.logger.error(f"{NEON_RED}Momentum calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_cci(self) -> pd.Series:
        """Calculates Commodity Channel Index (CCI)."""
        cci_values = self._calculate_cci(window=20)
        if not cci_values.empty:
            self.indicator_values["CCI"] = cci_values.iloc[-1]
        return cci_values

    def _calculate_cci(self, window: int = 20, constant: float = 0.015) -> pd.Series:
        """Internal CCI calculation."""
        try:
            typical_price = (self.df["high"] + self.df["low"] + self.df["close"]) / 3
            sma_typical_price = typical_price.rolling(window=window).mean()
            mean_deviation = typical_price.rolling(window=window).apply(lambda x: np.abs(x - x.mean()).mean(), raw=True)
            return (typical_price - sma_typical_price) / (constant * mean_deviation)
        except (KeyError, ZeroDivisionError) as e:
            self.logger.error(f"{NEON_RED}CCI calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_williams_r(self) -> pd.Series:
        """Calculates Williams %R."""
        wr_values = self._calculate_williams_r(window=14)
        if not wr_values.empty:
            self.indicator_values["Williams_R"] = wr_values.iloc[-1]
        return wr_values

    def _calculate_williams_r(self, window: int = 14) -> pd.Series:
        """Internal Williams %R calculation."""
        try:
            highest_high = self.df["high"].rolling(window=window).max()
            lowest_low = self.df["low"].rolling(window=window).min()
            return (highest_high - self.df["close"]) / (highest_high - lowest_low) * -100
        except KeyError as e:
            self.logger.error(f"{NEON_RED}Williams %R calculation error: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_mfi(self) -> pd.Series:
        """Calculates Money Flow Index (MFI)."""
        mfi_values = self._calculate_mfi(window=14)
        if not mfi_values.empty:
            self.indicator_values["MFI"] = mfi_values.iloc[-1]
        return mfi_values

    def _calculate_mfi(self, window: int = 14) -> pd.Series:
        """Internal MFI calculation."""
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

    def calculate_vwap(self) -> pd.Series:
        """Calculates Volume Weighted Average Price (VWAP)."""
        vwap_values = self._calculate_vwap()
        if not vwap_values.empty:
            self.indicator_values["VWAP"] = vwap_values.iloc[-1]
        return vwap_values

    def _calculate_vwap(self) -> pd.Series:
        """Internal VWAP calculation."""
        try:
            if "typical_price" not in self.df.columns:
                self.df["typical_price"] = (self.df["high"] + self.df["low"] + self.df["close"]) / 3
            return (self.df["volume"] * self.df["typical_price"]).cumsum() / self.df["volume"].cumsum()
        except KeyError as e:
            self.logger.error(f"{NEON_RED}VWAP calculation error: Missing column {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_psar(self) -> pd.Series:
        """Calculates Parabolic SAR (PSAR)."""
        psar_values = self._calculate_psar()
        if not psar_values.empty:
            self.indicator_values["PSAR"] = psar_values.iloc[-1]
        return psar_values

    def _calculate_psar(self, acceleration=0.01, max_acceleration=0.2) -> pd.Series:
        """Internal PSAR calculation."""
        psar = pd.Series(index=self.df.index, dtype="float64")
        psar.iloc[0] = self.df["low"].iloc[0]

        trend = 1
        ep = self.df["high"].iloc[0]
        af = acceleration

        for i in range(1, len(self.df)):
            if trend == 1:
                psar.iloc[i] = psar.iloc[i-1] + af * (ep - psar.iloc[i-1])
                if self.df["low"].iloc[i] < psar.iloc[i]:
                    trend = -1
                    psar.iloc[i] = ep
                    ep = self.df["low"].iloc[i]
                    af = acceleration
                else:
                    if self.df["high"].iloc[i] > ep:
                        ep = self.df["high"].iloc[i]
                        af = min(af + acceleration, max_acceleration)

            elif trend == -1:
                psar.iloc[i] = psar.iloc[i-1] + af * (ep - psar.iloc[i-1])
                if self.df["high"].iloc[i] > psar.iloc[i]:
                    trend = 1
                    psar.iloc[i] = ep
                    ep = self.df["high"].iloc[i]
                    af = acceleration
                else:
                    if self.df["low"].iloc[i] < ep:
                        ep = self.df["low"].iloc[i]
                        af = min(af + acceleration, max_acceleration)
        return psar

    def calculate_sma_10(self) -> pd.Series:
        """Calculates 10-period Simple Moving Average (SMA_10)."""
        sma_10_values = self._calculate_sma(window=10)
        if not sma_10_values.empty:
            self.indicator_values["SMA_10"] = sma_10_values.iloc[-1]
        return sma_10_values

    def _calculate_sma(self, window: int, series: pd.Series = None) -> pd.Series:
        """Internal SMA calculation function."""
        if series is None:
            if "close" not in self.df.columns:
                self.logger.error(f"{NEON_RED}Missing 'close' column for SMA calculation{RESET}")
                return pd.Series(dtype=float)
            series = self.df["close"]
        return series.rolling(window=window).mean()

    def calculate_stoch_rsi(self) -> pd.DataFrame:
        """Calculates Stochastic Relative Strength Index (Stoch RSI)."""
        stoch_rsi_df = self._calculate_stoch_rsi()
        if not stoch_rsi_df.empty:
            self.indicator_values["StochRSI_K"] = stoch_rsi_df["k"].iloc[-1]
            self.indicator_values["StochRSI_D"] = stoch_rsi_df["d"].iloc[-1]
        return stoch_rsi_df

    def _calculate_stoch_rsi(self, rsi_window: int = 14, stoch_window: int = 12, k_window: int = 3, d_window: int = 3) -> pd.DataFrame:
        """Internal Stoch RSI calculation."""
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

    def calculate_rsi(self, window: int = 14) -> pd.Series:
        """Calculates Relative Strength Index (RSI)."""
        rsi_values = self._calculate_rsi(window=window)
        if not rsi_values.empty:
            self.indicator_values["RSI"] = rsi_values.iloc[-1]
        return rsi_values

    def _calculate_rsi(self, window: int = 14) -> pd.Series:
        """Internal RSI calculation."""
        try:
            delta = self.df["close"].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
            rs = gain / loss
            rsi = np.where(loss == 0, 100, 100 - (100 / (1 + rs)))
            return pd.Series(rsi, index=self.df.index)
        except ZeroDivisionError:
            self.logger.error(f"{NEON_RED}RSI calculation error: Division by zero (handled). Returning NaN.{RESET}")
            return pd.Series(np.nan, index=self.df.index)
        except KeyError as e:
            self.logger.error(f"{NEON_RED}RSI calculation error: Missing column - {e}{RESET}")
            return pd.Series(dtype="float64")
        except Exception as e:
            self.logger.exception(f"{NEON_RED}Unexpected error during RSI calculation: {e}{RESET}")
            return pd.Series(dtype="float64")

    def calculate_bollinger_bands(self) -> pd.DataFrame:
        """Calculates Bollinger Bands."""
        bbands_df = self._calculate_bollinger_bands()
        if not bbands_df.empty:
            self.indicator_values["BB_Upper"] = bbands_df["bb_upper"].iloc[-1]
            self.indicator_values["BB_Middle"] = bbands_df["bb_mid"].iloc[-1]
            self.indicator_values["BB_Lower"] = bbands_df["bb_lower"].iloc[-1]
        return bbands_df

    def _calculate_bollinger_bands(self, period=20, std_dev=2) -> pd.DataFrame:
        """Internal Bollinger Bands calculation."""
        try:
            rolling_mean = self.df["close"].rolling(window=period).mean()
            rolling_std = self.df["close"].rolling(window=period).std()
            bb_upper = rolling_mean + (rolling_std * std_dev)
            bb_mid = rolling_mean
            bb_lower = rolling_mean - (rolling_std * std_dev)
            return pd.DataFrame({
                "bb_upper": bb_upper,
                "bb_mid": bb_mid,
                "bb_lower": bb_lower
            })
        except KeyError as e:
            self.logger.error(f"{NEON_RED}Bollinger Bands calculation error: {e}{RESET}")
            return pd.DataFrame()

    def _generate_scalping_signal(self, current_price: Decimal, orderbook_data: dict) -> str:
        """Generates scalping signals based on indicators and orderbook."""
        signal_score = 0

        # EMA Alignment check
        if self.config["indicators"]["ema_alignment"]:
            ema_alignment_score = self.calculate_ema_alignment()
            signal_score += ema_alignment_score * self.user_defined_weights.ema_alignment
            if ema_alignment_score == 1.0:
                self.scalping_signals["BUY"] += 1
            elif ema_alignment_score == -1.0:
                self.scalping_signals["SELL"] += 1

        # Momentum Check
        if self.config["indicators"]["momentum"]:
            momentum_val = self.calculate_momentum().iloc[-1]
            if momentum_val > 0:
                signal_score += self.user_defined_weights.momentum
                self.scalping_signals["BUY"] += 1
            elif momentum_val < 0:
                signal_score -= self.user_defined_weights.momentum
                self.scalping_signals["SELL"] += 1

        # Volume Confirmation
        if self.config["indicators"]["volume_confirmation"]:
            volume_ma = self.df["volume_ma"].iloc[-1]
            current_volume = self.df["volume"].iloc[-1]
            if current_volume > volume_ma * self.config["volume_confirmation_multiplier"]:
                signal_score += self.user_defined_weights.volume_confirmation
                self.scalping_signals["BUY"] += 1
            elif current_volume < volume_ma / self.config["volume_confirmation_multiplier"]:
                signal_score -= self.user_defined_weights.volume_confirmation
                self.scalping_signals["SELL"] += 1

        # Stochastic RSI Check
        if self.config["indicators"]["stoch_rsi"]:
            stoch_rsi_k = self.indicator_values.get("StochRSI_K", np.nan)
            stoch_rsi_d = self.indicator_values.get("StochRSI_D", np.nan)

            if stoch_rsi_k < self.config["stoch_rsi_oversold_threshold"] and stoch_rsi_d < self.config["stoch_rsi_oversold_threshold"]:
                signal_score += self.user_defined_weights.stoch_rsi + (self.config["stoch_rsi_confidence_boost"] / 10.0)
                self.scalping_signals["BUY"] += 1
            elif stoch_rsi_k > self.config["stoch_rsi_overbought_threshold"] and stoch_rsi_d > self.config["stoch_rsi_overbought_threshold"]:
                signal_score -= self.user_defined_weights.stoch_rsi + (self.config["stoch_rsi_confidence_boost"] / 10.0)
                self.scalping_signals["SELL"] += 1

        # RSI Check
        if self.config["indicators"]["rsi"]:
            rsi_val = self.indicator_values.get("RSI", np.nan)
            if rsi_val < 30:
                signal_score += self.user_defined_weights.rsi + (self.config["rsi_confidence_boost"] / 10.0)
                self.scalping_signals["BUY"] += 1
            elif rsi_val > 70:
                signal_score -= self.user_defined_weights.rsi + (self.config["rsi_confidence_boost"] / 10.0)
                self.scalping_signals["SELL"] += 1

        # CCI Check
        if self.config["indicators"]["cci"]:
            cci_val = self.indicator_values.get("CCI", np.nan)
            if cci_val < -100:
                signal_score += self.user_defined_weights.cci
                self.scalping_signals["BUY"] += 1
            elif cci_val > 100:
                signal_score -= self.user_defined_weights.cci
                self.scalping_signals["SELL"] += 1

        # Williams %R Check
        if self.config["indicators"]["wr"]:
            wr_val = self.indicator_values.get("Williams_R", np.nan)
            if wr_val < -80:
                signal_score += self.user_defined_weights.wr
                self.scalping_signals["BUY"] += 1
            elif wr_val > -20:
                signal_score -= self.user_defined_weights.wr
                self.scalping_signals["SELL"] += 1

        # PSAR Check
        if self.config["indicators"]["psar"]:
            psar_val = self.indicator_values.get("PSAR", np.nan)
            last_close = self.df["close"].iloc[-1]
            if last_close > psar_val:
                signal_score += self.user_defined_weights.psar
                self.scalping_signals["BUY"] += 1
            elif last_close < psar_val:
                signal_score -= self.user_defined_weights.psar
                self.scalping_signals["SELL"] += 1

        # SMA_10 Check
        if self.config["indicators"]["sma_10"]:
            sma_10_val = self.indicator_values.get("SMA_10", np.nan)
            last_close = self.df["close"].iloc[-1]
            if last_close > sma_10_val:
                signal_score += self.user_defined_weights.sma_10
                self.scalping_signals["BUY"] += 1
            elif last_close < sma_10_val:
                signal_score -= self.user_defined_weights.sma_10
                self.scalping_signals["SELL"] += 1

        # VWAP Check
        if self.config["indicators"]["vwap"]:
            vwap_val = self.indicator_values.get("VWAP", np.nan)
            last_close = self.df["close"].iloc[-1]
            if last_close > vwap_val:
                signal_score += self.user_defined_weights.vwap
                self.scalping_signals["BUY"] += 1
            elif last_close < vwap_val:
                signal_score -= self.user_defined_weights.vwap
                self.scalping_signals["SELL"] += 1

        if signal_score >= self.config["scalping_signal_threshold"]:
            return "BUY"
        elif signal_score <= -self.config["scalping_signal_threshold"]:
            return "SELL"
        else:
            return "HOLD"

    def generate_trading_signal(self, current_price: Decimal, orderbook_data: dict) -> str:
        """Generates trading signal and confirms with orderbook."""
        self.scalping_signals = {"BUY": 0, "SELL": 0}
        scalping_signal = self._generate_scalping_signal(current_price, orderbook_data)
        confirmed_signal = confirm_signal_with_orderbook(scalping_signal, current_price, orderbook_data, self.config, self.logger)
        return confirmed_signal


def analyze_symbol(symbol: str, config: dict):
    """Analyzes trading data for a given symbol and outputs scalping signals."""
    logger = setup_logger(symbol)
    logger.info(f"Analyzing symbol: {symbol} with interval: {config['interval']}")

    klines_interval = config['interval']
    analysis_interval = str(config['analysis_interval'])

    klines = fetch_klines(symbol, klines_interval, limit=250, logger=logger)
    if klines.empty:
        logger.error(f"{NEON_RED}Failed to fetch klines for {symbol}. Aborting analysis.{RESET}")
        return

    orderbook_data = fetch_orderbook(symbol, limit=config['orderbook_limit'], logger=logger)
    if not orderbook_data:
        logger.warning(f"{NEON_YELLOW}Could not fetch orderbook data for {symbol}. Scalping signals might be less accurate.{RESET}")

    analyzer = TradingAnalyzer(klines.copy(), logger, config, symbol, klines_interval)

    # Calculate indicators
    analyzer.df["typical_price"] = (analyzer.df["high"] + analyzer.df["low"] + analyzer.df["close"]) / 3
    analyzer.df["volume_ma"] = analyzer.calculate_sma(analyzer.config["volume_ma_period"], series=analyzer.df["volume"])

    if config['indicators']['ema_alignment']:
        analyzer.calculate_ema_alignment()
    if config['indicators']['momentum']:
        analyzer.calculate_momentum()
    if config['indicators']['cci']:
        analyzer.calculate_cci()
    if config['indicators']['wr']:
        analyzer.calculate_williams_r()
    if config['indicators']['mfi']:
        analyzer.calculate_mfi()
    if config['indicators']['vwap']:
        # Add typical_price calculation before VWAP
        analyzer.df["typical_price"] = (analyzer.df["high"] + analyzer.df["low"] + analyzer.df["close"]) / 3
        analyzer.calculate_vwap()
    if config['indicators']['psar']:
        analyzer.calculate_psar()
    if config['indicators']['sma_10']:
        analyzer.calculate_sma_10()
    if config['indicators']['stoch_rsi']:
        analyzer.calculate_stoch_rsi()
    if config['indicators']['rsi']:
        analyzer.calculate_rsi()
    if config['indicators']['bollinger_bands']:
        analyzer.calculate_bollinger_bands()

    current_price_decimal = fetch_current_price(symbol, logger)
    if current_price_decimal is None:
        logger.error(f"{NEON_RED}Failed to fetch current price for {symbol}. Using last close price for signal generation.{RESET}")
        current_price_decimal = Decimal(str(klines['close'].iloc[-1]))

    trading_signal = analyzer.generate_trading_signal(current_price_decimal, orderbook_data)

    account_balance = get_account_balance(API_KEY, API_SECRET, logger) # Fetch account balance
    if account_balance is None:
        logger.error(f"{NEON_RED}Could not fetch account balance, position sizing disabled.{RESET}")
        position_size = Decimal('0')
    else:
        atr_value = analyzer.calculate_atr(window=analyzer.config['atr_period']).iloc[-1]
        position_size = calculate_position_size(account_balance, atr_value, config['price_change_threshold'], config['account_risk_percent'], current_price_decimal)

    output_message = (
        f"\n{NEON_BLUE}--- Scalping Analysis for {symbol} ({klines_interval}) ---{RESET}\n"
        f"Current Price (JST): {NEON_GREEN}{current_price_decimal}{RESET} - {datetime.now(TIMEZONE).strftime('%Y-%m-%d %H:%M:%S %Z%z')}\n"
        f"Scalping Signal: {NEON_GREEN}{trading_signal}{RESET}\n"
        f"Calculated Position Size: {NEON_YELLOW}{position_size} Contracts{RESET}\n"  # Output position size
    )
    output_message += f"  Indicator Values:\n"
    for indicator, value in analyzer.indicator_values.items():
        output_message += f"    {indicator}: {NEON_YELLOW}{value:.4f}{RESET}\n"
    output_message += f"  Scalping Signal Breakdown:\n"
    output_message += f"    Buy Signals: {NEON_GREEN}{analyzer.scalping_signals['BUY']}{RESET}, Sell Signals: {NEON_RED}{analyzer.scalping_signals['SELL']}{RESET}\n"

    print(output_message)
    logger.info(output_message)


async def main():
    """Main function to run scalping analysis."""
    symbol = input(f"{NEON_YELLOW}Enter symbol to analyze (e.g., BTCUSDT): {RESET}").upper()
    interval = input(f"{NEON_YELLOW}Enter interval (e.g., 1m, 5m, 15m): {RESET}").lower()

    if interval not in VALID_INTERVALS:
        print(f"{NEON_RED}Invalid interval. Please choose from: {VALID_INTERVALS}{RESET}")
        return

    CONFIG['interval'] = interval
    CONFIG['symbol'] = symbol  # Set symbol in config
    symbols = [symbol]

    print(f"{NEON_CYAN}--- Neonta Scalping Bot v1.1 ---{RESET}")  # Version update
    print(f"{NEON_CYAN}--- Analyzing market for scalping opportunities ---{RESET}\n")

    for symbol in symbols:
        analyze_symbol(symbol, CONFIG)
        time.sleep(1)

    print(f"{NEON_CYAN}\n--- Scalping Analysis Complete ---{RESET}")


if __name__ == "__main__":
    asyncio.run(main())
