import pandas as pd
import numpy as np
from .base import Indicator

class Momentum(Indicator):
    """
    Enhanced Momentum Indicator with Smoothed and Normalized Variations.

    Calculates:
        - Standard Momentum
        - Exponential Moving Average (EMA) of Momentum (Smoothed Momentum)
        - Z-score Normalized Momentum
    """
    def __init__(self, config):
        super().__init__(config)
        self.length = config.get('length', 10)  # Length for standard momentum calculation
        self.ema_length = config.get('ema_length', 20) # Length for EMA smoothing of momentum
        self.zscore_window = config.get('zscore_window', 30) # Window for Z-score normalization


    def calculate(self, data: pd.DataFrame) -> pd.DataFrame:
        """
        Calculates Enhanced Momentum indicators and returns them in a DataFrame.

        Returns DataFrame with columns:
            - 'momentum': Standard Momentum
            - 'momentum_ema': Exponential Moving Average of Momentum (Smoothed Momentum)
            - 'momentum_zscore': Z-score Normalized Momentum
        """
        close_prices = data['close']
        momentum_series = self._calculate_momentum(close_prices, self.length)

        momentum_ema_series = self._calculate_ema_momentum(momentum_series, self.ema_length)
        momentum_zscore_series = self._calculate_zscore_momentum(momentum_series, self.zscore_window)

        momentum_df = pd.DataFrame({
            'momentum': momentum_series,
            'momentum_ema': momentum_ema_series,
            'momentum_zscore': momentum_zscore_series,
        })
        return momentum_df

    def _calculate_momentum(self, series: pd.Series, length: int) -> pd.Series:
        """Calculates the Standard Momentum indicator."""
        return series.diff(length)

    def _calculate_ema_momentum(self, momentum_series: pd.Series, ema_length: int) -> pd.Series:
        """Calculates the Exponential Moving Average (EMA) of the Momentum."""
        return momentum_series.ewm(span=ema_length, adjust=False).mean()

    def _calculate_zscore_momentum(self, momentum_series: pd.Series, zscore_window: int) -> pd.Series:
        """Calculates the Z-score Normalized Momentum."""
        rolling_mean = momentum_series.rolling(window=zscore_window, min_periods=zscore_window // 2).mean() # min_periods for early values
        rolling_std = momentum_series.rolling(window=zscore_window, min_periods=zscore_window // 2).std(ddof=0) # ddof=0 for population std

        # Avoid division by zero for standard deviation
        rolling_std_safe = np.where(rolling_std == 0, 1e-9, rolling_std) # Replace 0 with a tiny value

        zscore_momentum = (momentum_series - rolling_mean) / rolling_std_safe
        return zscore_momentum


    def get_indicator_name(self) -> str:
        return "Enhanced Momentum"