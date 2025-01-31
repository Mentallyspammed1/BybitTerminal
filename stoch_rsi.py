import pandas as pd
from typing import Dict, Any
from .base import Indicator

class StochRSI(Indicator):
    """
    Calculates the Stochastic Relative Strength Index (Stoch RSI).

    The Stochastic RSI is a momentum indicator that measures the level of RSI
    relative to its high-low range over a user-defined period. It is used to
    identify overbought and oversold conditions and potential trend reversals.

    Configuration parameters:
        length_rsi (int):  Period for RSI calculation. Default is 14.
        length_k (int):    Period for calculating %K of the Stochastic RSI. Default is 3.
        length_d (int):    Period for calculating %D (moving average of %K). Default is 3.

    Returns:
        pd.DataFrame: DataFrame with columns 'stoch_k' and 'stoch_d', representing
                      the Stochastic RSI values. The index of the DataFrame
                      will be aligned with the input DataFrame or Series.

    Example Usage:
    >>> import pandas as pd
    >>> data = {'close': [10, 11, 12, 11, 13, 14, 13, 15, 16, 15]}
    >>> df = pd.DataFrame(data)
    >>> config = {'length_rsi': 14, 'length_k': 3, 'length_d': 3}
    >>> stoch_rsi_indicator = StochasticRSI(config)
    >>> stoch_rsi_df = stoch_rsi_indicator.calculate(df)
    >>> print(stoch_rsi_df)
         stoch_k    stoch_d
    0        NaN        NaN
    1        NaN        NaN
    2        NaN        NaN
    3        NaN        NaN
    4        NaN        NaN
    5        NaN        NaN
    6        NaN        NaN
    7        NaN        NaN
    8        NaN        NaN
    9        NaN        NaN #  (Note: Output will have NaNs at the beginning due to rolling calculations)
    """
    def __init__(self, config: Dict[str, Any]):
        """
        Initializes the StochasticRSI indicator.

        Args:
            config (Dict[str, Any]): Configuration dictionary.
                                     Must contain keys: 'length_rsi', 'length_k', 'length_d'.
                                     If keys are missing, default values are used.
        """
        super().__init__(config)
        self.length_rsi = config.get("length_rsi", 14)
        self.length_k = config.get("length_k", 3)
        self.length_d = config.get("length_d", 3)

        # Input validation for configuration parameters - ensuring correct types
        if not isinstance(self.length_rsi, int) or self.length_rsi <= 0:
            raise ValueError(f"Invalid 'length_rsi' in config: {self.length_rsi}. Must be a positive integer.")
        if not isinstance(self.length_k, int) or self.length_k <= 0:
            raise ValueError(f"Invalid 'length_k' in config: {self.length_k}. Must be a positive integer.")
        if not isinstance(self.length_d, int) or self.length_d <= 0:
            raise ValueError(f"Invalid 'length_d' in config: {self.length_d}. Must be a positive integer.")

    def calculate(self, data: pd.DataFrame | pd.Series) -> pd.DataFrame:
        """
        Calculates Stochastic RSI.

        Accepts either a Pandas DataFrame with a 'close' column or a Pandas Series
        representing closing prices.

        Args:
            data (pd.DataFrame | pd.Series): DataFrame with 'close' column or a Series
                                              of closing prices.

        Returns:
            pd.DataFrame: DataFrame containing 'stoch_k' and 'stoch_d' columns.
                          Returns an empty DataFrame if input data is invalid.
        """
        if isinstance(data, pd.DataFrame):
            if 'close' not in data.columns:
                raise ValueError("Input DataFrame must contain a 'close' column.")
            close_series = data['close'] # Extract 'close' series if DataFrame is provided
        elif isinstance(data, pd.Series):
            close_series = data # Use the Series directly if provided
        else:
            raise ValueError("Input data must be a Pandas DataFrame or a Pandas Series.")

        if close_series.empty: # Handle empty input Series/DataFrame
            return pd.DataFrame({'stoch_k': pd.Series(dtype='float64'), 'stoch_d': pd.Series(dtype='float64')}) # Return empty DataFrame

        if close_series.isnull().any(): # Handle NaN values in the close series by dropping them.
            close_series = close_series.dropna()
            print("Warning: Input 'close' series contains NaN values. Dropping NaN values before Stochastic RSI calculation.")
            if close_series.empty: # Check again if series is empty after dropping NaNs
                 return pd.DataFrame({'stoch_k': pd.Series(dtype='float64'), 'stoch_d': pd.Series(dtype='float64')}) # Return empty DataFrame if all were NaNs

        return self._calculate_stoch_rsi(close_series, self.length_rsi, self.length_k, self.length_d).set_index(close_series.index) # Align index with input close series

    def _calculate_stoch_rsi(self, close: pd.Series, length_rsi: int = 14, length_k: int = 3, length_d: int = 3) -> pd.DataFrame:
            """
            Calculates Stochastic RSI core logic.

            This is a private method performing the actual Stochastic RSI calculation.

            Args:
                close (pd.Series): Pandas Series of closing prices.
                length_rsi (int): Period for RSI calculation.
                length_k (int): Period for calculating %K.
                length_d (int): Period for calculating %D.

            Returns:
                pd.DataFrame: DataFrame with 'stoch_k' and 'stoch_d' columns.
            """
            rsi = self._calculate_rsi(close, length_rsi) # Calculate RSI first

            rsi_min = rsi.rolling(window=length_k).min() # Lowest RSI value over the last 'length_k' periods
            rsi_max = rsi.rolling(window=length_k).max() # Highest RSI value over the last 'length_k' periods

            # Stochastic %K calculation: Position of the current RSI relative to its recent range
            stoch_k = 100 * (rsi - rsi_min) / (rsi_max - rsi_min)

            # Stochastic %D calculation: Smoothed version of %K (using Simple Moving Average)
            stoch_d = stoch_k.rolling(window=length_d).mean()

            return pd.DataFrame({'stoch_k': stoch_k, 'stoch_d': stoch_d})

    def _calculate_rsi(self, series: pd.Series, length: int = 14) -> pd.Series:
        """
        Calculates Relative Strength Index (RSI).

        This is a helper function to calculate the RSI.

        Args:
            series (pd.Series): Pandas Series of price data (typically closing prices).
            length (int): Period for RSI calculation.

        Returns:
            pd.Series: Pandas Series of RSI values.
        """
        delta = series.diff() # Price difference between current and previous period
        up_days = delta.where(delta >= 0, 0) # Series of positive price changes (ups)
        down_days = -delta.where(delta < 0, 0) # Series of negative price changes (downs), made positive

        roll_up = up_days.rolling(window=length).mean() # Average gain over 'length' periods
        roll_down = down_days.rolling(window=length).mean() # Average loss over 'length' periods

        rs = roll_up / roll_down # Calculate Relative Strength (Ratio of average up to average down)
        rsi = 100.0 - (100.0 / (1.0 + rs)) # RSI formula

        return rsi

    def get_indicator_name(self) -> str:
        """
        Returns the name of the indicator.

        Returns:
            str: Indicator name - "Stochastic RSI"
        """
        return "Stochastic RSI"