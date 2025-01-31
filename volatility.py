# indicators/volatility.py
from .base import Indicator
import pandas as pd
import numpy as np
from typing import Dict, Any

class Volatility:
    def __init__(self, config: Dict[str, Any]) -> None:
        """
        Initializes the Volatility indicator with multiple volatility measures.

        Config can include:
            - window: The lookback period for various calculations (default: 14).
            - atr_period: The lookback period for ATR calculation (default: 14).
            - bollinger_std_dev: The number of standard deviations for Bollinger Bands (default: 2).
            - use_std: Whether to include standard deviation-based volatility (default: True).
            - use_atr: Whether to include ATR-based volatility (default: True).
            - use_bollinger: Whether to include Bollinger Bands width-based volatility (default: True).
            - use_parkinson: Whether to include Parkinson volatility (default: False).
            - use_garman_klass: Whether to include Garman-Klass volatility (default: False).
            - use_rogers_satchell: Whether to include Rogers-Satchell volatility (default: False).
            - use_yang_zhang: Whether to include Yang-Zhang volatility (default: False).
            - normalization_method: Method for normalizing volatility measures ('minmax', 'zscore', or None, default: 'zscore').
        """
        self.config = config
        self.window = self.config.get("window", 14)
        self.atr_period = self.config.get("atr_period", 14)
        self.bollinger_std_dev = self.config.get("bollinger_std_dev", 2)

        self.use_std = self.config.get("use_std", True)
        self.use_atr = self.config.get("use_atr", True)
        self.use_bollinger = self.config.get("use_bollinger", True)
        self.use_parkinson = self.config.get("use_parkinson", False)
        self.use_garman_klass = self.config.get("use_garman_klass", False)
        self.use_rogers_satchell = self.config.get("use_rogers_satchell", False)
        self.use_yang_zhang = self.config.get("use_yang_zhang", False)
        self.normalization_method = self.config.get("normalization_method", "zscore")

    def calculate(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculates multiple volatility measures based on the configuration.
        """
        volatility_measures = {}

        if self.use_std:
            volatility_measures["std_volatility"] = self._calculate_std_volatility(df)
        if self.use_atr:
            volatility_measures["atr_volatility"] = self._calculate_atr_volatility(df)
        if self.use_bollinger:
            volatility_measures["bollinger_volatility"] = self._calculate_bollinger_volatility(df)
        if self.use_parkinson:
            volatility_measures["parkinson_volatility"] = self._calculate_parkinson_volatility(df)
        if self.use_garman_klass:
            volatility_measures["garman_klass_volatility"] = self._calculate_garman_klass_volatility(df)
        if self.use_rogers_satchell:
            volatility_measures["rogers_satchell_volatility"] = self._calculate_rogers_satchell_volatility(df)
        if self.use_yang_zhang:
            volatility_measures["yang_zhang_volatility"] = self._calculate_yang_zhang_volatility(df)
        
        volatility_df = pd.DataFrame(volatility_measures)

        # Normalize the volatility measures
        if self.normalization_method == "minmax":
            volatility_df = (volatility_df - volatility_df.min()) / (volatility_df.max() - volatility_df.min())
        elif self.normalization_method == "zscore":
            volatility_df = (volatility_df - volatility_df.mean()) / volatility_df.std()

        # Calculate the composite volatility as the mean of normalized measures
        volatility_df["volatility"] = volatility_df.mean(axis=1)

        return volatility_df

    def _calculate_std_volatility(self, df: pd.DataFrame) -> pd.Series:
        """Calculates volatility as the standard deviation of returns."""
        if len(df) < self.window:
            return pd.Series(index=df.index, dtype="float64")
        returns = df["close"].pct_change()
        return returns.rolling(window=self.window).std() * np.sqrt(self.window)

    def _calculate_atr_volatility(self, df: pd.DataFrame) -> pd.Series:
        """Calculates volatility using the Average True Range (ATR)."""
        if len(df) < self.atr_period:
            return pd.Series(index=df.index, dtype="float64")
        high_low = df["high"] - df["low"]
        high_close = np.abs(df["high"] - df["close"].shift())
        low_close = np.abs(df["low"] - df["close"].shift())
        tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        return tr.rolling(window=self.atr_period).mean()

    def _calculate_bollinger_volatility(self, df: pd.DataFrame) -> pd.Series:
        """Calculates volatility using the Bollinger Bands width."""
        if len(df) < self.window:
            return pd.Series(index=df.index, dtype="float64")
        rolling_mean = df["close"].rolling(window=self.window).mean()
        rolling_std = df["close"].rolling(window=self.window).std()
        upper_band = rolling_mean + (rolling_std * self.bollinger_std_dev)
        lower_band = rolling_mean - (rolling_std * self.bollinger_std_dev)
        return upper_band - lower_band

    def _calculate_parkinson_volatility(self, df: pd.DataFrame) -> pd.Series:
        """
        Calculates the Parkinson volatility estimator.
        This is a measure of volatility that only uses the high and low prices of the day.
        """
        if len(df) < self.window:
            return pd.Series(index=df.index, dtype="float64")

        log_hl = np.log(df["high"] / df["low"])
        return np.sqrt((1.0 / (4.0 * self.window * np.log(2.0))) * (log_hl ** 2).rolling(window=self.window).sum())

    def _calculate_garman_klass_volatility(self, df: pd.DataFrame) -> pd.Series:
        """
        Calculates the Garman-Klass volatility estimator.
        This is an improvement on Parkinson's estimator, as it also takes into account the opening and closing prices.
        """
        if len(df) < self.window:
            return pd.Series(index=df.index, dtype="float64")
        
        log_hl = np.log(df["high"] / df["low"])
        log_co = np.log(df["close"] / df["open"])
        
        term1 = 0.5 * (log_hl ** 2)
        term2 = (2 * np.log(2) - 1) * (log_co ** 2)
        
        return np.sqrt((1.0 / self.window) * (term1 - term2).rolling(window=self.window).sum())

    def _calculate_rogers_satchell_volatility(self, df: pd.DataFrame) -> pd.Series:
        """
        Calculates the Rogers-Satchell volatility estimator.
        This estimator is similar to Garman-Klass but is designed to handle situations where the opening price is outside the high-low range.
        """
        if len(df) < self.window:
            return pd.Series(index=df.index, dtype="float64")
        
        log_ho = np.log(df["high"] / df["open"])
        log_lo = np.log(df["low"] / df["open"])
        log_co = np.log(df["close"] / df["open"])
        log_hc = np.log(df["high"] / df["close"])
        log_lc = np.log(df["low"] / df["close"])
        
        return np.sqrt((1.0 / self.window) * (log_ho * log_hc + log_lo * log_lc).rolling(window=self.window).sum())

    def _calculate_yang_zhang_volatility(self, df: pd.DataFrame) -> pd.Series:
        """
        Calculates the Yang-Zhang volatility estimator.
        This is a weighted average of the Rogers-Satchell estimator and the standard deviation of returns.
        """
        if len(df) < self.window:
            return pd.Series(index=df.index, dtype="float64")
        
        k = 0.34 / (1.34 + (self.window + 1) / (self.window - 1))
        
        rogers_satchell = self._calculate_rogers_satchell_volatility(df)
        std_dev = self._calculate_std_volatility(df)
        
        return np.sqrt(k * (rogers_satchell ** 2) + (1 - k) * (std_dev ** 2))