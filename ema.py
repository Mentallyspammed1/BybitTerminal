# indicators/ema.py

import pandas as pd
from .base import Indicator

class EMA(Indicator):

    def __init__(self, config):
        super().__init__(config)
        self.length_short = config.get('length_short', 20)
        self.length_long = config.get('length_long', 50)

    def calculate(self, data: pd.DataFrame) -> pd.DataFrame:
        """Calculates the Exponential Moving Average."""
        ema_short = self._calculate_ema(data['close'], self.length_short)
        ema_long = self._calculate_ema(data['close'], self.length_long)
        return pd.DataFrame({'ema_short': ema_short, 'ema_long': ema_long})

    def _calculate_ema(self, series: pd.Series, length: int) -> pd.Series:
        """Calculates Exponential Moving Average."""
        return series.ewm(span=length, adjust=False).mean()

    def get_indicator_name(self) -> str:
        return "EMA"