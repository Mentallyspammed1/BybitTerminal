import os
from dotenv import load_dotenv
from pybit import HTTP
import numpy as np

# Load environment variables from .env file
load_dotenv()

# Initialize Bybit client
api_key = os.getenv('BYBIT_API_KEY')
api_secret = os.getenv('BYBIT_API_SECRET')
session = HTTP(
    endpoint="https://api.bybit.com",
    api_key=api_key,
    api_secret=api_secret
)

# Parameters for the strategy
symbol = 'BTCUSD'  # Trading pair
timeframe = '1'    # 1-minute candles
fast_ma_period = 10
slow_ma_period = 50
rsi_period = 14
rsi_overbought = 70
rsi_oversold = 30
quantity = 1       # Quantity to trade

def get_klines(symbol, interval, limit=100):
    """ Fetch historical klines/candles """
    response = session.query_kline(
        symbol=symbol,
        interval=interval,
        limit=limit
    )
    return response['result']

def calculate_ma(data, period):
    """ Calculate Moving Average """
    return np.convolve(data, np.ones(period), 'valid') / period

def calculate_rsi(data, period):
    """ Calculate RSI """
    delta = np.diff(data)
    gain = np.where(delta > 0, delta, 0)
    loss = np.where(delta < 0, -delta, 0)
    avg_gain = np.zeros_like(data)
    avg_loss = np.zeros_like(data)
    avg_gain[period] = np.mean(gain[:period])
    avg_loss[period] = np.mean(loss[:period])

    for i in range(period + 1, len(data)):
        avg_gain[i] = (avg_gain[i - 1] * (period - 1) + gain[i - 1]) / period
        avg_loss[i] = (avg_loss[i - 1] * (period - 1) + loss[i - 1]) / period

    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

def trading_strategy(symbol, timeframe, fast_ma_period, slow_ma_period, rsi_period, rsi_overbought, rsi_oversold, quantity):
    # Fetch historical data
    klines = get_klines(symbol, timeframe)
    close_prices = np.array([float(kline['close']) for kline in klines])

    # Calculate Moving Averages
    fast_ma = calculate_ma(close_prices, fast_ma_period)
    slow_ma = calculate_ma(close_prices, slow_ma_period)

    # Calculate RSI
    rsi = calculate_rsi(close_prices, rsi_period)

    # Trading signals
    signals = []
    for i in range(len(close_prices) - max(fast_ma_period, slow_ma_period, rsi_period)):
        if fast_ma[i] > slow_ma[i] and rsi[i] < rsi_oversold:
            signals.append('BUY')
        elif fast_ma[i] < slow_ma[i] and rsi[i] > rsi_overbought:
            signals.append('SELL')
        else:
            signals.append('HOLD')

    # Execute trades based on the last signal
    last_signal = signals[-1]
    if last_signal == 'BUY':
        # Place a buy order
        session.place_active_order(
            symbol=symbol,
            side='Buy',
            order_type='Market',
            qty=quantity,
            time_in_force='PostOnly'
        )
        print(f"Placed a BUY order for {quantity} {symbol}")
    elif last_signal == 'SELL':
        # Place a sell order
        session.place_active_order(
            symbol=symbol,
            side='Sell',
            order_type='Market',
            qty=quantity,
            time_in_force='PostOnly'
        )
        print(f"Placed a SELL order for {quantity} {symbol}")
    else:
        print(f"HOLD position for {symbol}")

# Run the trading strategy
trading_strategy(symbol, timeframe, fast_ma_period, slow_ma_period, rsi_period, rsi_overbought, rsi_oversold, quantity
