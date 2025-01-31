# indicators/atr.py

import pandas as pd
import numpy as np
from typing import Dict, Any
from .base import Indicator

class ATR:
    def __init__(self, config: Dict[str, Any]) -> None:
        """
        Initializes the ATR indicator.

        Config can include:
            - length: The lookback period for the ATR calculation (default: 14).
        """
        self.config = config
        self.length = self.config.get("length", 14)

    def calculate(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculates the Average True Range (ATR).
        """
        if len(df) < self.length:
            return pd.Series(index=df.index, dtype="float64")  # Return empty series if not enough data

        high_low = df["high"] - df["low"]
        high_close = np.abs(df["high"] - df["close"].shift())
        low_close = np.abs(df["low"] - df["close"].shift())

        tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        atr = tr.rolling(window=self.length).mean()

        df[f'atr_{self.length}'] = atr
        return df