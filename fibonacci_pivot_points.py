# indicators/fibonacci_pivot_points.py

import pandas as pd
from typing import Dict, Any, List
from colorama import Fore, Style
from .base import Indicator

class FibonacciPivotPoints:
    def __init__(self, config: Dict[str, Any]) -> None:
        """
        Initializes the FibonacciPivotPoints indicator with significantly enhanced logic.

        Config can include:
            - custom_fib_levels: A dictionary to override default Fibonacci levels.
            - extended_levels: A boolean to calculate extended Fibonacci levels.
            - level_precision: An integer specifying the decimal precision for levels.
            - sma_period: Integer for the Simple Moving Average (SMA) period for trend context.
            - stoch_rsi_period: Integer for Stoch RSI period to gauge overbought/oversold.
            - stoch_rsi_k: Integer for Stoch RSI %K smoothing period.
            - stoch_rsi_d: Integer for Stoch RSI %D smoothing period.
            - volume_multiplier: Float for volume spike detection threshold.
        """
        self.config = config
        self.fib_levels = self.config.get("custom_fib_levels", {
            "r3": 1.618,
            "r2": 1.0,
            "r1": 0.618,
            "pivot": 0.0,
            "s1": -0.618,
            "s2": -1.0,
            "s3": -1.618,
        })
        self.extended_levels = self.config.get("extended_levels", True)
        self.level_precision = self.config.get("level_precision", 2)
        self.sma_period = self.config.get("sma_period", 20)  # Default SMA period for trend
        self.stoch_rsi_period = self.config.get("stoch_rsi_period", 14)
        self.stoch_rsi_k_period = self.config.get("stoch_rsi_k", 3)
        self.stoch_rsi_d_period = self.config.get("stoch_rsi_d", 3)
        self.volume_multiplier = self.config.get("volume_multiplier", 1.5) # Volume spike threshold

        if self.extended_levels:
            self.fib_levels.update({
                "r5": 2.618,
                "s5": -2.618,
                "r4": 2.0,
                "s4": -2.0,
            })

        # Precompute level names for signal generation
        self.level_names = {
            level: self.get_signal_name(level) for level in self.fib_levels
        }

    def calculate(self, df: pd.DataFrame, current_price: float = None) -> pd.DataFrame:
        """
        Calculates Fibonacci pivot points for each row in the DataFrame.

        If 'current_price' is provided, it's ignored, as the method now calculates pivots
        based on each row's high, low, and close.
        """

        pivot_points_list = []

        for index, row in df.iterrows():
            high = row["high"]
            low = row["low"]
            close = row["close"]
            pivot = (high + low + close) / 3
            diff = high - low

            pivot_points = {
                level: round(pivot + (diff * factor), self.level_precision)
                for level, factor in self.fib_levels.items()
            }
            pivot_points_list.append(pivot_points)
        return pd.DataFrame(pivot_points_list, index=df.index)

    def get_signal_name(self, price_level: str) -> str:
        """
        Returns the name of the signal with color based on the price level.
        """
        if price_level == "pivot":
            return f"{Fore.CYAN}{Style.BRIGHT}Pivot{Style.RESET_ALL}"
        elif price_level.startswith("r"):
            return f"{Fore.RED}{Style.BRIGHT}{price_level.upper()}{Style.RESET_ALL}"
        elif price_level.startswith("s"):
            return f"{Fore.GREEN}{Style.BRIGHT}{price_level.upper()}{Style.RESET_ALL}"
        else:
            return price_level.upper()

    def _calculate_stoch_rsi(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculates Stochastic RSI.
        """
        rsi_period = self.stoch_rsi_period
        k_period = self.stoch_rsi_k_period
        d_period = self.stoch_rsi_d_period

        rsi = df['close'].diff().apply(lambda x: x if x > 0 else 0).rolling(window=rsi_period).mean() / \
              abs(df['close'].diff()).rolling(window=rsi_period).mean() * 100
        if rsi.isna().all(): # Handle case where RSI calculation results in NaN
            return pd.DataFrame({'stoch_k': pd.Series(dtype='float64'), 'stoch_d': pd.Series(dtype='float64')}, index=df.index)


        stoch_k = (rsi - rsi.rolling(window=k_period).min()) / (rsi.rolling(window=k_period).max() - rsi.rolling(window=k_period).min()) * 100
        stoch_d = stoch_k.rolling(window=d_period).mean()

        return pd.DataFrame({'stoch_k': stoch_k, 'stoch_d': stoch_d}, index=df.index)


    def generate_trading_signals(self, df: pd.DataFrame, current_price: float) -> List[str]:
        """
        Generates significantly enhanced trading signals based on current price,
        Fibonacci levels, trend (using SMA), Stoch RSI, and contextual logic.
        """
        pivot_points = self.calculate(df, current_price)
        signals = []

        # Calculate SMA for trend detection
        df['SMA'] = df['close'].rolling(window=self.sma_period).mean()
        current_sma = df['SMA'].iloc[-1]

        trend_direction = "Sideways"
        if current_price > current_sma:
            trend_direction = "Uptrend"
        elif current_price < current_sma:
            trend_direction = "Downtrend"

        # Calculate Stochastic RSI
        stoch_rsi_df = self._calculate_stoch_rsi(df)
        if not stoch_rsi_df.empty: # Proceed only if Stoch RSI data is successfully calculated
            stoch_k = stoch_rsi_df["stoch_k"].iloc[-1]
            stoch_d = stoch_rsi_df["stoch_d"].iloc[-1]
        else:
            stoch_k = None # Indicate Stoch RSI couldn't be calculated
            stoch_d = None


        # Volume Spike Detection
        current_volume = df["volume"].iloc[-1]
        previous_volume = df["volume"].iloc[-2] if len(df) > 1 else 0 # Handle edge case for short dataframes
        volume_spike = current_volume > previous_volume * self.volume_multiplier

        # Proximity Threshold (e.g., 0.5% of price difference between levels) - Adaptive based on price range
        typical_diff = (pivot_points.iloc[0]['r1'] - pivot_points.iloc[0]['pivot']) # Example diff, can average across levels for robustness
        proximity_threshold = typical_diff * 0.005 if typical_diff > 0 else abs(pivot_points.iloc[0]['s1'] - pivot_points.iloc[0]['pivot']) * 0.005 if abs(pivot_points.iloc[0]['s1'] - pivot_points.iloc[0]['pivot']) * 0.005 else 0


        # Iterate through all calculated pivot point levels
        for level, price in pivot_points.iloc[0].items():
            level_name = self.get_signal_name(level)

            # --- Resistance Levels (R) - Enhanced Logic ---
            if level.startswith("r"):
                distance_to_level = current_price - price
                is_proximal = 0 < distance_to_level <= proximity_threshold # Price slightly above level
                is_very_proximal = abs(distance_to_level) <= proximity_threshold # Price very close to level (either side)
                is_strongly_above = current_price > price + proximity_threshold # Price clearly above level


                if is_strongly_above:
                    if level == "r5":
                        signal_strength = "Extreme Overbought"
                    elif level in ["r4", "r3"]:
                        signal_strength = "Strong Overbought"
                    else: # r2, r1
                        signal_strength = "Moderately Overbought"

                    signal_text = f"{Fore.RED}{Style.BRIGHT}{signal_strength} - Potential Reversal at {level_name}: {price:.2f}{Style.RESET_ALL} (Trend: {trend_direction})"

                    if stoch_k is not None and stoch_d is not None and stoch_k > 70 and stoch_d > 70: # Stoch RSI Overbought Confirmation
                         signal_text += f" {Fore.RED}(Stoch RSI Overbought Confirm){Style.RESET_ALL}"
                    if volume_spike:
                        signal_text += f" {Fore.YELLOW}(Volume Spike){Style.RESET_ALL}" # Volume spike adds confluence

                    signals.append(signal_text)


                elif is_proximal: # Price slightly above resistance - Watching for rejection
                    signal_strength = "Weak Sell Signal Watch"
                    signal_text = f"{Fore.YELLOW}{Style.BRIGHT}{signal_strength} near {level_name}: {price:.2f} - Potential Rejection (Trend: {trend_direction}){Style.RESET_ALL}"
                    if stoch_k is not None and stoch_d is not None and stoch_k > 60 and stoch_d > 60: # Stoch RSI approaching overbought
                        signal_text += f" {Fore.YELLOW}(Stoch RSI Approaching Overbought){Style.RESET_ALL}"
                    signals.append(signal_text)


                elif is_very_proximal and current_price <= price: # Price very close to level and at or below it - Possible rejection
                    signal_strength = "Moderate Sell Signal - Rejection Possible"
                    signal_text = f"{Fore.RED}{Style.BRIGHT}{signal_strength} at {level_name}: {price:.2f} (Trend: {trend_direction}){Style.RESET_ALL}"
                    if stoch_k is not None and stoch_d is not None and stoch_k > 50 and stoch_d > 50: # Stoch RSI moderate overbought
                         signal_text += f" {Fore.YELLOW}(Stoch RSI Moderately Overbought){Style.RESET_ALL}"
                    if volume_spike:
                        signal_text += f" {Fore.YELLOW}(Volume Spike){Style.RESET_ALL}" # Volume spike adds confluence
                    signals.append(signal_text)


                elif current_price < price - proximity_threshold: # Price clearly below resistance
                    if trend_direction == "Downtrend":
                        signals.append(
                             f"{Fore.WHITE}{Style.DIM}Price Below {level_name}: {price:.2f} - Downtrend Persists (Resistance Overhead){Style.RESET_ALL} (Trend: {trend_direction})"
                         )
                    else: # Uptrend or Sideways
                        signals.append(
                            f"{Fore.WHITE}{Style.DIM}Price Below {level_name}: {price:.2f} - Resistance Level Overhead (Trend: {trend_direction}){Style.RESET_ALL}"
                        )
                elif current_price <= price and not is_very_proximal and not is_proximal : # Price at or just below level, but not very close
                    signals.append(
                        f"{Fore.WHITE}{Style.DIM}Near {level_name}: {price:.2f} - Resistance in Vicinity (Trend: {trend_direction}){Style.RESET_ALL}"
                    )


            # --- Support Levels (S) - Enhanced Logic ---
            elif level.startswith("s"):
                distance_to_level = price - current_price
                is_proximal = 0 < distance_to_level <= proximity_threshold # Price slightly below level
                is_very_proximal = abs(distance_to_level) <= proximity_threshold # Price very close to level (either side)
                is_strongly_below = current_price < price - proximity_threshold # Price clearly below support


                if is_strongly_below:
                    if level == "s5":
                        signal_strength = "Extreme Oversold"
                    elif level in ["s4", "s3"]:
                        signal_strength = "Strong Oversold"
                    else: # s2, s1
                        signal_strength = "Moderately Oversold"

                    signal_text = f"{Fore.GREEN}{Style.BRIGHT}{signal_strength} - Potential Rebound at {level_name}: {price:.2f}{Style.RESET_ALL} (Trend: {trend_direction})"
                    if stoch_k is not None and stoch_d is not None and stoch_k < 30 and stoch_d < 30: # Stoch RSI Oversold Confirmation
                        signal_text += f" {Fore.GREEN}(Stoch RSI Oversold Confirm){Style.RESET_ALL}"
                    if volume_spike: # Check for volume spike on oversold conditions - potential bullish sign but need confirmation
                        signal_text += f" {Fore.YELLOW}(Volume Spike - Possible Accumulation){Style.RESET_ALL}" # Volume spike adds confluence
                    signals.append(signal_text)


                elif is_proximal: # Price slightly below support - Watching for bounce
                    signal_strength = "Weak Buy Signal Watch"
                    signal_text = f"{Fore.YELLOW}{Style.BRIGHT}{signal_strength} near {level_name}: {price:.2f} - Potential Bounce (Trend: {trend_direction}){Style.RESET_ALL}"
                    if stoch_k is not None and stoch_d is not None and stoch_k < 40 and stoch_d < 40: # Stoch RSI approaching oversold
                        signal_text += f" {Fore.YELLOW}(Stoch RSI Approaching Oversold){Style.RESET_ALL}"
                    signals.append(signal_text)


                elif is_very_proximal and current_price >= price: # Price very close to level and at or above it - Possible bounce
                    signal_strength = "Moderate Buy Signal - Rebound Possible"
                    signal_text = f"{Fore.GREEN}{Style.BRIGHT}{signal_strength} at {level_name}: {price:.2f} (Trend: {trend_direction}){Style.RESET_ALL}"
                    if stoch_k is not None and stoch_d is not None and stoch_k < 50 and stoch_d < 50: # Stoch RSI moderately oversold
                        signal_text += f" {Fore.YELLOW}(Stoch RSI Moderately Oversold){Style.RESET_ALL}"
                    if volume_spike:
                        signal_text += f" {Fore.YELLOW}(Volume Spike - Potential Accumulation){Style.RESET_ALL}" # Volume spike adds confluence
                    signals.append(signal_text)


                elif current_price > price + proximity_threshold: # Price clearly above support
                    if trend_direction == "Uptrend":
                        signals.append(
                             f"{Fore.WHITE}{Style.DIM}Price Above {level_name}: {price:.2f} - Uptrend Support Holding (Support Below){Style.RESET_ALL} (Trend: {trend_direction})"
                         )
                    else: # Downtrend or Sideways
                        signals.append(
                            f"{Fore.WHITE}{Style.DIM}Price Above {level_name}: {price:.2f} - Support Level Broken (Trend: {trend_direction}){Style.RESET_ALL}"
                        )
                elif current_price >= price and not is_very_proximal and not is_proximal: # Price at or just above level, but not very close
                    signals.append(
                        f"{Fore.WHITE}{Style.DIM}Near {level_name}: {price:.2f} - Support in Vicinity (Trend: {trend_direction}){Style.RESET_ALL}"
                    )


            # --- Pivot Level - Contextual Signals ---
            elif level == "pivot":
                if current_price > price + proximity_threshold:
                    signal_strength = "Pivot Support Confirmed"
                    signal_text = f"{Fore.YELLOW}{Style.BRIGHT}{signal_strength} at {level_name}: {price:.2f} - Pivot acting as Support (Trend: {trend_direction}){Style.RESET_ALL}"
                    if trend_direction == "Uptrend": # Stronger signal in uptrend
                        signal_text += f" {Fore.GREEN}(Uptrend Confirmation){Style.RESET_ALL}"
                    signals.append(signal_text)


                elif current_price < price - proximity_threshold:
                    signal_strength = "Pivot Resistance Confirmed"
                    signal_text = f"{Fore.YELLOW}{Style.BRIGHT}{signal_strength} at {level_name}: {price:.2f} - Pivot acting as Resistance (Trend: {trend_direction}){Style.RESET_ALL}"
                    if trend_direction == "Downtrend": # Stronger signal in downtrend
                        signal_text += f" {Fore.RED}(Downtrend Confirmation){Style.RESET_ALL}"
                    signals.append(signal_text)

                elif is_very_proximal: # Price very close to Pivot
                     signals.append(f"{Fore.WHITE}{Style.BRIGHT}Price Consolidating Near {level_name}: {price:.2f} - Watch for Breakout (Trend: {trend_direction}){Style.RESET_ALL}")

                else: # Price near pivot, but not very close or clearly above/below
                    signals.append(f"{Fore.WHITE}{Style.BRIGHT}Near {level_name}: {price:.2f} - Pivot Point in Play (Trend: {trend_direction}){Style.RESET_ALL}")


        return signals
