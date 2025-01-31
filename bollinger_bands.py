import pandas as pd
import numpy as np
from .base import Indicator


class BollingerBands:
   
        def __init__(self, config, num_std=2.0): 

    def calculate(self, data: pd.DataFrame) -> pd.DataFrame:
        if not isinstance(data, pd.DataFrame):
            raise ValueError("Input 'data' must be a pandas DataFrame.")
        if data.empty:
            return pd.DataFrame(index=data.index)
        if 'close' not in data.columns:
            raise ValueError("DataFrame must contain a 'close' column for Bollinger Bands calculation.")
        if len(data) < self.window:
            print(f"Warning: Not enough data points ({len(data)}) to calculate Bollinger Bands with window {self.window}. Returning NaN for Bollinger Bands.")
            return pd.DataFrame({
                'bollinger_mavg': pd.Series(index=data.index, dtype='float64'),
                'bollinger_upper': pd.Series(index=data.index, dtype='float64'),
                'bollinger_lower': pd.Series(index=data.index, dtype='float64'),
                'percent_b': pd.Series(index=data.index, dtype='float64')
            })

        mavg = data['close'].rolling(window=self.window, min_periods=self.window).mean()
        stddev = data['close'].rolling(window=self.window, min_periods=self.window).std()
        upper_band = mavg + (self.num_std * stddev)
        lower_band = mavg - (self.num_std * stddev)
        percent_b = ((data['close'] - lower_band) / (upper_band - lower_band)) * 100

        bollinger_bands_df = pd.DataFrame({
            'bollinger_mavg': mavg,
            'bollinger_upper': upper_band,
            'bollinger_lower': lower_band,
            'percent_b': percent_b
        }, index=data.index)

        return bollinger_bands_df
