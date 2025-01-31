# indicators/pivot_points.py

import pandas as pd
from typing import Dict, Any, Literal

class PivotPoints:
    """
    Calculates various types of Pivot Points (Standard, Fibonacci, Camarilla).
    """
    def __init__(self, config: Dict[str, Any]) -> None:
        """
        Initializes the Pivot Points indicator.
        Config is not used directly in this indicator, but included for
        potential future configuration and consistency across indicators.
        """
        self.config = config # Kept for potential future use

    def calculate(self, df: pd.DataFrame, pivot_type: Literal["standard", "fibonacci", "camarilla"] = "standard") -> pd.DataFrame:
        """
        Calculates Pivot Points based on the specified type for each row in the DataFrame.

        Args:
            df (pd.DataFrame): DataFrame with 'high', 'low', 'close' columns.
            pivot_type (Literal["standard", "fibonacci", "camarilla"]): Type of Pivot Points to calculate.
                Defaults to "standard".

        Returns:
            pd.DataFrame: DataFrame containing pivot point levels (pivot, r1, s1, r2, s2, r3, s3)
                          for each row of the input DataFrame.
        """
        if pivot_type == "standard":
            return self._calculate_standard_pivots(df)
        elif pivot_type == "fibonacci":
            return self._calculate_fibonacci_pivots(df)
        elif pivot_type == "camarilla":
            return self._calculate_camarilla_pivots(df)
        else:
            raise ValueError(f"Unsupported pivot_type: {pivot_type}. Choose from 'standard', 'fibonacci', or 'camarilla'.")

    def _calculate_standard_pivots(self, df: pd.DataFrame) -> pd.DataFrame:
        """Calculates Standard Pivot Points."""
        pivot = (df["high"] + df["low"] + df["close"]) / 3
        r1 = (2 * pivot) - df["low"]
        s1 = (2 * pivot) - df["high"]
        r2 = pivot + (df["high"] - df["low"])
        s2 = pivot - (df["high"] - df["low"])
        r3 = r2 + (df["high"] - df["low"]) # Corrected R3 and S3 for standard pivots - more conventional formulas
        s3 = s2 - (df["high"] - df["low"])

        pivot_df = pd.DataFrame({
            "pivot": pivot,
            "r1": r1,
            "s1": s1,
            "r2": r2,
            "s2": s2,
            "r3": r3,
            "s3": s3,
        })
        return pivot_df

    def _calculate_fibonacci_pivots(self, df: pd.DataFrame) -> pd.DataFrame:
        """Calculates Fibonacci Pivot Points."""
        pivot = (df["high"] + df["low"] + df["close"]) / 3
        diff = df["high"] - df["low"]

        r1 = pivot + (diff * 0.382)
        s1 = pivot - (diff * 0.382)
        r2 = pivot + (diff * 0.618)
        s2 = pivot - (diff * 0.618)
        r3 = pivot + (diff * 1.000) # Often considered R3 in Fibonacci pivots, sometimes 1.618 is also used
        s3 = pivot - (diff * 1.000) # Often considered S3 in Fibonacci pivots, sometimes 1.618 is also used

        pivot_df = pd.DataFrame({
            "pivot": pivot,
            "r1": r1,
            "s1": s1,
            "r2": r2,
            "s2": s2,
            "r3": r3,
            "s3": s3,
        })
        return pivot_df

    def _calculate_camarilla_pivots(self, df: pd.DataFrame) -> pd.DataFrame:
        """Calculates Camarilla Pivot Points."""
        pivot = (df["high"].shift(1) + df["low"].shift(1) + df["close"].shift(1)) / 3 # Using previous day's HLC for Camarilla
        if pivot.iloc[0] is pd.NA: # Handle first row edge case
            pivot.iloc[0] = (df["high"].iloc[0] + df["low"].iloc[0] + df["close"].iloc[0]) / 3 # If first row, use current day's data

        diff = df["high"].shift(1) - df["low"].shift(1) # Using previous day's range
        if diff.iloc[0] is pd.NA: # Handle first row edge case
             diff.iloc[0] = df["high"].iloc[0] - df["low"].iloc[0]

        r1 = df["close"].shift(1) + (diff * 0.127) # R1 and S1 are based on previous close
        s1 = df["close"].shift(1) - (diff * 0.127)
        r2 = df["close"].shift(1) + (diff * 0.236)
        s2 = df["close"].shift(1) - (diff * 0.236)
        r3 = df["close"].shift(1) + (diff * 0.382)
        s3 = df["close"].shift(1) - (diff * 0.382)
        r4 = df["close"].shift(1) + (diff * 0.500) # Camarilla often goes up to R4 and S4
        s4 = df["close"].shift(1) - (diff * 0.500)

        pivot_df = pd.DataFrame({
            "pivot": pivot,
            "r1": r1,
            "s1": s1,
            "r2": r2,
            "s2": s2,
            "r3": r3,
            "s3": s3,
            "r4": r4, # Added R4 and S4 for Camarilla
            "s4": s4,
        })
        return pivot_df