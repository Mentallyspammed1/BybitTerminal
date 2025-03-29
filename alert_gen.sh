#!/bin/bash

# --- CCXT Bybit SMS Alerts via Termux API (using pandas_ta) ---

# **Prerequisites:**
# 1. Termux app installed on your Android device.
# 2. Termux:API app installed in Termux (via Google Play or F-Droid).
# 3. Allow Termux:API permissions (SMS, storage if needed).
# 4. Python and pip installed in Termux (pkg install python).
# 5. ccxt, python-dotenv, and pandas_ta installed (pip install ccxt python-dotenv pandas_ta).
# 6. .env file with BYBIT_API_KEY and BYBIT_SECRET in the script's directory.

# **Phone Number for SMS Alerts:**
PHONE_NUMBER="6364866381"  # Replace with the actual phone number

# --- Helper function (same as before) ---
_ccxt_bybit_python() {
  python -c "
import ccxt, os, sys
from dotenv import load_dotenv

load_dotenv()

exchange = ccxt.bybit({
    'apiKey': os.getenv('BYBIT_API_KEY'),
    'secret': os.getenv('BYBIT_SECRET'),
})

if not exchange.apiKey or not exchange.secret:
    print('Error: BYBIT_API_KEY and BYBIT_SECRET must be set in .env file.')
    sys.exit(1)

${1} # Python code passed as argument
  "
}

# --- Function to Send SMS via Termux API ---
send_sms() {
  MESSAGE="$1"
  termux-api-sms-send -n "$PHONE_NUMBER" "$MESSAGE"
  if [ $? -eq 0 ]; then
    echo "SMS alert sent to $PHONE_NUMBER: $MESSAGE"
  else
    echo "Error sending SMS alert via Termux API. Is Termux:API installed and permissions granted?"
  fi
}

# --- TA and Orderbook Analysis Function ---
analyze_market() {
  SYMBOL="BTC/USDT" # Symbol to analyze
  TIMEFRAME="15m"   # OHLCV timeframe for RSI

  _ccxt_bybit_python "
import ccxt, pandas_ta as ta # Using pandas_ta instead of talib
import numpy as np
import pandas as pd # Import pandas for DataFrame

symbol = '$SYMBOL'
timeframe = '$TIMEFRAME'
limit = 20 # For RSI calculation

try:
    ohlcv = exchange.fetch_ohlcv(symbol, timeframe=timeframe, limit=limit)
    if not ohlcv:
        print('Could not fetch OHLCV data.')
        sys.exit(1)

    df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume']) # Create Pandas DataFrame
    df['close'] = pd.to_numeric(df['close']) # Ensure 'close' is numeric
    rsi_series = ta.rsi(df['close'], length=14) # Calculate 14-period RSI using pandas_ta, returns Pandas Series
    rsi = rsi_series.iloc[-1] # Get the last RSI value from the Series

    orderbook = exchange.fetch_order_book(symbol, limit=10) # Fetch top 10 levels
    if not orderbook or not orderbook['bids'] or not orderbook['asks']:
        print('Could not fetch orderbook.')
        sys.exit(1)

    best_bid = orderbook['bids'][0][0]
    best_ask = orderbook['asks'][0][0]
    bid_volume_top5 = sum([bid[1] for bid in orderbook['bids'][:5]]) # Sum volume of top 5 bids
    ask_volume_top5 = sum([ask[1] for ask in orderbook['asks'][:5]]) # Sum volume of top 5 asks

    print(f'RSI for {symbol} ({timeframe}): {rsi:.2f}')
    print(f'Top Bid: {best_bid}, Top Ask: {best_ask}')
    print(f'Top 5 Bid Volume: {bid_volume_top5:.2f}, Top 5 Ask Volume: {ask_volume_top5:.2f}')

    # --- Alerting Logic (within Python for simplicity, could be moved to bash) ---
    alert_messages = []

    # RSI Overbought/Oversold Alert
    if rsi > 70:
        alert_messages.append(f'RSI Overbought for {symbol} ({timeframe}): RSI = {rsi:.2f}')
    elif rsi < 30:
        alert_messages.append(f'RSI Oversold for {symbol} ({timeframe}): RSI = {rsi:.2f}')

    # Orderbook Imbalance Alert (Example: Bid volume significantly higher than ask volume at top levels)
    if bid_volume_top5 > ask_volume_top5 * 2: # Bid volume more than 2x ask volume
        alert_messages.append(f'Orderbook Bid Volume Imbalance for {symbol}: Bid Vol > 2x Ask Vol')
    elif ask_volume_top5 > bid_volume_top5 * 2: # Ask volume more than 2x bid volume
        alert_messages.append(f'Orderbook Ask Volume Imbalance for {symbol}: Ask Vol > 2x Bid Vol')

    # Price Shift Alert (Example: Significant change in top bid/ask from previous run - needs state persistence for real implementation)
    # ... (State persistence is more complex in bash, consider using a file or database for persistent variables)
    # For this example, we'll skip price shift alert due to state management complexity in bash script

    # --- Output Alerts to stdout and trigger SMS if alerts are present ---
    if alert_messages:
        print('\\nAlerts triggered:')
        for msg in alert_messages:
            print(f'  - {msg}')
            print(f'SMS_ALERT::{msg}') # Mark alert messages for bash to easily parse
    else:
        print('\\nNo alerts triggered.')

except Exception as e:
    print(f'Analysis Error: {e}')
    sys.exit(1)
  " | while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == SMS_ALERT::* ]]; then
      ALERT_MESSAGE="${line#SMS_ALERT::}" # Remove prefix
      send_sms "$ALERT_MESSAGE"
    fi
  done
}

# --- Main Script Execution ---

echo "Starting market analysis for $SYMBOL ($TIMEFRAME)..."
analyze_market

echo "Analysis complete."

# --- Example: Run analysis every minute (using 'watch' - for demonstration, adjust as needed) ---
# watch -n 60 ./your_script_name.sh
```

**Key Changes:**

1.  **Prerequisites Updated:** Added `pandas_ta` to the list of prerequisites.
2.  **Installation Instructions Updated:**  Mentioned `pandas_ta` in `pip install` command.
3.  **Python Script Modifications:**
    *   **Replaced `import talib` with `import pandas_ta as ta`:**  Now using `pandas_ta` library.
    *   **Imported `pandas`:** `import pandas as pd` is added to work with Pandas DataFrames.
    *   **Created Pandas DataFrame:**
        ```python
        df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
        df['close'] = pd.to_numeric(df['close'])
        ```
        The OHLCV data is converted into a Pandas DataFrame, which is the preferred input format for `pandas_ta`.  Ensured 'close' column is numeric for `pandas_ta`.
    *   **RSI Calculation using `pandas_ta`:**
        ```python
        rsi_series = ta.rsi(df['close'], length=14) # Calculate RSI, returns Pandas Series
        rsi = rsi_series.iloc[-1] # Get last RSI value
        ```
        `pandas_ta.rsi()` is used to calculate RSI. It returns a Pandas Series. We extract the last value using `.iloc[-1]`.

**Before Running (with `pandas_ta`):**

1.  **Install Dependencies in Termux:**
    ```bash
    pkg install python
    pip install ccxt python-dotenv pandas_ta numpy
    pkg install termux-api
    ```
    **Make sure to install `pandas_ta` using pip.** You no longer need `ta-lib-bin`.
2.  **Create `.env` File:** Ensure your `.env` file is in the same directory with Bybit API keys.
3.  **Allow Termux:API Permissions:** Grant Termux:API permissions in Android settings.
4.  **Make Script Executable:** `chmod +x your_script_name.sh`

**To Run:**

```bash
./your_script_name.sh
```

**To Run Periodically (Example - every minute):**

```bash
watch -n 60 ./your_script_name.sh
