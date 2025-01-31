# indicators/obv.py
import pandas as pd
from .base import Indicator

class OBV(Indicator):
    def __init__(self, config: dict = None):
        super().__init__("obv", config)

    def calculate(self, df: pd.DataFrame) -> pd.DataFrame:
        """Calculates the On-Balance Volume (OBV)."""
        df["price_change"] = df["close"].diff()
        df["volume_change"] = 0
        df.loc[df["price_change"] > 0, "volume_change"] = df["volume"]
        df.loc[df["price_change"] < 0, "volume_change"] = -df["volume"]
        df["obv"] = df["volume_change"].cumsum()
        return df[["obv"]].fillna(0) # Return only OBV column and handle initial NaN