# indicators/atr_trailing_stop.py
# Pyrrrmethus, the Python Coding Wizard and Bybit v5 API Sage! - ATR Trailing Stop Indicator - Forging the Dynamic Shield of Profit!

import pandas as pd
import numpy as np
from typing import Dict, Any

class ATRTrailingStop:
    """
    Pyrrrmethus, the ATR Trailing Stop Forger! - Crafting the Dynamic Shield of Profit and Risk Management.

    The ATR Trailing Stop dynamically adjusts stop-loss levels based on market volatility,
    using the Average True Range (ATR). It is a sentinel, guarding profits and limiting losses
    with adaptive vigilance.
    """

    def __init__(self, config: Dict[str, Any]):
        """
        Pyrrrmethus, the Trailing Stop Artificer, initializes the ATR Trailing Stop with enchanted configurations.

        Parameters:
            config (Dict[str, Any]): A dictionary containing configuration parameters.
                Expected keys:
                    'atr_length' (int, optional): Length for ATR calculation. Default: 14 periods, the classic measure.
                    'atr_multiplier' (float, optional): Multiplier for ATR to set the trailing stop distance. Default: 3.0, a balanced guard.
        """
        self.atr_length = config.get('atr_length', 14) # ATR Length - How far back we gaze into volatility's range (Default: 14)
        self.atr_multiplier = config.get('atr_multiplier', 3.0) # ATR Multiplier - How many multiples of ATR to set stop distance (Default: 3.0)


    def calculate(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Pyrrrmethus, the Trailing Stop Artificer, invokes the Calculating Ritual to forge the ATR Trailing Stop values.

        Args:
            df (pd.DataFrame): DataFrame containing OHLCV data - The raw materials for crafting the shield.
                Must contain columns: 'high', 'low', 'close'.

        Returns:
            pd.DataFrame: DataFrame with the enchanted 'atr_trailing_stop' column - The Dynamic Shield, ready to guard your trades.
        """
        if df.empty:
            # Empty Dataframe? A silent shield in a silent market.
            return pd.DataFrame(columns=['atr_trailing_stop']) # Return empty DataFrame with the column


        # --- 1. Calculate True Range (TR) - Measuring the Volatility's Breath ---
        high_low_range = df['high'] - df['low'] # Range within the current bar
        high_prev_close_range = abs(df['high'] - df['close'].shift(1)) # Range from current high to previous close
        low_prev_close_range = abs(df['low'] - df['close'].shift(1)) # Range from current low to previous close

        true_range = pd.concat([high_low_range, high_prev_close_range, low_prev_close_range], axis=1).max(axis=1) # Max of the three ranges is the True Range

        # --- 2. Calculate Average True Range (ATR) - Smoothing the Volatility's Fury ---
        atr = true_range.rolling(window=self.atr_length, min_periods=self.atr_length).mean() # Simple Moving Average of True Range over the configured length


        # --- 3. Initialize Trailing Stop Levels - Setting the Initial Shield Positions ---
        atr_trailing_stop = pd.Series(index=df.index, dtype='float64') # Initialize Series to hold Trailing Stop values

        # Determine initial direction based on the first data point (handle edge case of first ATR value being NaN)
        first_atr = atr.iloc[self.atr_length-1] # Get the first calculated ATR value (after rolling window is full)
        if not np.isnan(first_atr): # Proceed only if we have a valid first ATR value
            initial_long_stop = df['low'].iloc[self.atr_length-1] - (self.atr_multiplier * first_atr) # Initial Long Stop below initial low
            initial_short_stop = df['high'].iloc[self.atr_length-1] + (self.atr_multiplier * first_atr) # Initial Short Stop above initial high

            atr_trailing_stop.iloc[self.atr_length-1] = initial_long_stop if df['close'].iloc[self.atr_length-1] > df['close'].iloc[self.atr_length-2] else initial_short_stop # Determine initial stop direction

        # --- 4. Iterate and Calculate Trailing Stop - Dynamically Adjusting the Shield with Market Flow ---
        for i in range(self.atr_length, len(df)): # Start from where ATR is first calculated and valid
            current_atr = atr.iloc[i] # Current ATR value
            if np.isnan(current_atr): # Skip if current ATR is NaN (shouldn't happen after initial ATR)
                atr_trailing_stop.iloc[i] = atr_trailing_stop.iloc[i-1] # Carry forward previous valid trailing stop if ATR is unexpectedly NaN
                continue # Skip to the next iteration

            prev_atr_trailing_stop = atr_trailing_stop.iloc[i-1] # Previous Trailing Stop value
            current_close = df['close'].iloc[i] # Current Close price
            prev_close = df['close'].iloc[i-1] # Previous Close price
            current_high = df['high'].iloc[i] # Current High price
            current_low = df['low'].iloc[i] # Current Low price


            if prev_atr_trailing_stop is None or np.isnan(prev_atr_trailing_stop): # Handle potential NaN at start (though unlikely now with initialization)
                # Re-initialize if previous is NaN - Rare edge case handling for robustness
                if not np.isnan(current_atr): # Only initialize if current ATR is valid
                    if current_close > prev_close:
                         atr_trailing_stop.iloc[i] = current_low - (self.atr_multiplier * current_atr) # Initialize long stop
                    else:
                        atr_trailing_stop.iloc[i] = current_high + (self.atr_multiplier * current_atr) # Initialize short stop
                else: # If even current ATR is NaN, carry forward previous valid stop (if any) or leave as NaN
                    atr_trailing_stop.iloc[i] = atr_trailing_stop.iloc[i-1] if i > self.atr_length else np.nan
                continue # Proceed to next iteration after handling re-initialization


            if current_close > prev_close: # Uptrend - Shield moves below price
                long_stop_level = max(prev_atr_trailing_stop, current_low - (self.atr_multiplier * current_atr)) # Raise stop if previous stop is higher, or set new stop below current low
                atr_trailing_stop.iloc[i] = long_stop_level # Set the new Trailing Stop level for Uptrend

            elif current_close < prev_close: # Downtrend - Shield moves above price
                short_stop_level = min(prev_atr_trailing_stop, current_high + (self.atr_multiplier * current_atr)) # Lower stop if previous stop is lower, or set new stop above current high
                atr_trailing_stop.iloc[i] = short_stop_level # Set the new Trailing Stop level for Downtrend
            else:
                atr_trailing_stop.iloc[i] = prev_atr_trailing_stop # If close unchanged, maintain previous stop level - Stability in stillness


        # --- 5. Construct and Return DataFrame ---
        atr_ts_df = pd.DataFrame({'atr_trailing_stop': atr_trailing_stop}) # Create DataFrame with the ATR Trailing Stop series
        return atr_ts_df # Return the DataFrame shield, ready for battle!
