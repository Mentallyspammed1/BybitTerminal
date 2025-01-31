import pandas as pd
from colorama import Fore, Style


class RSI:
    """Calculates the Relative Strength Index (RSI)."""

    def __init__(self, config):
        """Initializes the RSI with a given length."""
        self.length = config.get(
            "length", 14
        )  # Default to 14 if length is not provided

    def calculate(self, df):
        """Calculates the RSI for a given DataFrame.

        Args:
            df (pd.DataFrame): DataFrame containing a 'Close' column.

        Returns:
            pd.Series: RSI values for the given data. Returns empty Series if errors.
        """
        if df.empty:
            print(
                Fore.YELLOW
                + Style.BRIGHT
                + "Warning: Empty DataFrame provided for RSI calculation."
            )
            return pd.Series(dtype="float64")

        if "Close" not in df.columns:
            print(
                Fore.RED
                + Style.BRIGHT
                + "Error: 'Close' column is required in DataFrame for RSI calculation."
            )
            return pd.Series(dtype="float64")

        close_prices = df["Close"]
        if len(close_prices) <= 1:
            print(
                Fore.YELLOW
                + Style.BRIGHT
                + "Warning: Insufficient 'Close' prices for RSI calculation."
            )
            return pd.Series(dtype="float64")

        # Calculate price differences
        delta = close_prices.diff()
        if (
            delta.isnull().all()
        ):  # if diff results in all nan values, return empty series
            print(
                Fore.YELLOW
                + Style.BRIGHT
                + "Warning: Identical 'Close' prices provided for RSI calculation (resulting in NaN delta)."
            )
            return pd.Series(dtype="float64")
        delta = delta.dropna()

        # Separate gains and losses
        gains = delta.where(delta > 0, 0)
        losses = -delta.where(delta < 0, 0)

        # Calculate average gains and average losses using rolling mean
        avg_gains = gains.rolling(window=self.length, min_periods=1).mean()
        avg_losses = losses.rolling(window=self.length, min_periods=1).mean()

        # Calculate relative strength (RS)
        with pd.option_context(
            "mode.use_inf_as_na", True
        ):  # set inf as nan for division handling
            rs = avg_gains / avg_losses

        # Calculate RSI
        rsi = 100 - (100 / (1 + rs))
        return rsi.replace(
            [float("inf"), float("-inf")], pd.NA
        ).dropna()  # Remove inf / nan values

    def display_in_terminal(self, rsi_values, symbol):
        """Displays RSI values in a terminal-friendly format.

        Args:
            rsi_values (pd.Series): Series of RSI values to display.
            symbol (str): The symbol being analyzed (e.g., BTCUSDT).
        """
        if rsi_values.empty:
            print(Fore.YELLOW + Style.BRIGHT + "No RSI values to display.")
            return

        print(Fore.WHITE + Style.BRIGHT + f"  Symbol: {Fore.GREEN}{symbol}")
        print(Fore.WHITE + Style.BRIGHT + f"  RSI Length: {Fore.GREEN}{self.length}")

        for index, rsi_value in rsi_values.items():
            # Format index to datetime
            # THIS WAS THE PROBLEM LINE! I REMOVED THE `#` AND ADDED THE INDENT
            print(f"  RSI = {Fore.CYAN}{rsi_value:.2f}")

        last_rsi = rsi_values.iloc[-1] if not rsi_values.empty else "N/A"
        print(Fore.WHITE + Style.BRIGHT + f"  Last RSI: {Fore.CYAN}{last_rsi:.2f}")
