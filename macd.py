# indicators/macd.py

import pandas as pd
from typing import Dict, Any
from .base import Indicator

class MACD:
    def __init__(self, config: Dict[str, Any]) -> None:
        """
        Initializes the MACD indicator.

        Config can include:
            - fast_length: The lookback period for the fast EMA (default: 12).
            - slow_length: The lookback period for the slow EMA (default: 26).
            - signal_length: The lookback period for the signal line EMA (default: 9).
        """
        self.config = config
        self.fast_length = self.config.get("fast_length", 12)
        self.slow_length = self.config.get("slow_length", 26)
        self.signal_length = self.config.get("signal_length", 9)

    def calculate(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculates the Moving Average Convergence Divergence (MACD).
        """
        ema_fast = df["close"].ewm(span=self.fast_length, adjust=False).mean()
        ema_slow = df["close"].ewm(span=self.slow_length, adjust=False).mean()

        # Corrected column names to lowercase:
        df["macd"] = ema_fast - ema_slow  # Lowercase
        df["macd_signal"] = df["macd"].ewm(span=self.signal_length, adjust=False).mean()  # Lowercase
        df["macd_hist"] = df["macd"] - df["macd_signal"]  # Lowercase
        return df
