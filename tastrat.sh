#!/bin/bash

# Ensure the script is run with bash
if [ -z "$BASH_VERSION" ]; then
    echo "Please run this script with bash: bash setup_terminal.sh"
    exit 1
fi

# Define the project root directory
PROJECT_DIR="BybitTerminal"
INDICATORS_DIR="$PROJECT_DIR/indicators"
STRATEGIES_DIR="$PROJECT_DIR/strategies"

# Create directories
echo "Creating project directories..."
mkdir -p "$INDICATORS_DIR" "$STRATEGIES_DIR"

# Function to create a file with content
create_file() {
    local file_path="$1"
    local content="$2"
    echo "Creating $file_path..."
    touch "$file_path"
    echo "$content" > "$file_path"
}

# SMA Indicator (Scalping: period=5, MA=3)
create_file "$INDICATORS_DIR/sma.py" "$(cat << 'EOF'
import ccxt

def calculate_sma(exchange, symbol="BTCUSDT", timeframe="1m", period=5, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < period + ma_period:
            return None, "Insufficient data for SMA."
        sma = [sum(closes[i - period + 1:i + 1]) / period for i in range(period - 1, len(closes))]
        ma_sma = [sum(sma[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(sma))]
        cross = "Bullish" if len(sma) >= 2 and sma[-2] < ma_sma[-2] and sma[-1] > ma_sma[-1] else "Bearish" if len(sma) >= 2 and sma[-2] > ma_sma[-2] and sma[-1] < ma_sma[-1] else "No Cross"
        return (sma, ma_sma), f"SMA({period}): {sma[-1]:.2f}, MA({ma_period}): {ma_sma[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating SMA: {e}"
EOF
)"

# EMA Indicator (Scalping: period=5, MA=3)
create_file "$INDICATORS_DIR/ema.py" "$(cat << 'EOF'
import ccxt

def calculate_ema(exchange, symbol="BTCUSDT", timeframe="1m", period=5, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < period + ma_period:
            return None, "Insufficient data for EMA."
        multiplier = 2 / (period + 1)
        ema = [sum(closes[:period]) / period]
        for price in closes[period:]:
            ema.append((price * multiplier) + (ema[-1] * (1 - multiplier)))
        ma_ema = [sum(ema[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(ema))]
        cross = "Bullish" if len(ema) >= 2 and ema[-2] < ma_ema[-2] and ema[-1] > ma_ema[-1] else "Bearish" if len(ema) >= 2 and ema[-2] > ma_ema[-2] and ema[-1] < ma_ema[-1] else "No Cross"
        return (ema, ma_ema), f"EMA({period}): {ema[-1]:.2f}, MA({ma_period}): {ma_ema[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating EMA: {e}"
EOF
)"

# MACD Indicator (Scalping: fast=6, slow=13, signal=3, MA=3)
create_file "$INDICATORS_DIR/macd.py" "$(cat << 'EOF'
import ccxt

def calculate_macd(exchange, symbol="BTCUSDT", timeframe="1m", fast=6, slow=13, signal=3, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < slow + signal + ma_period:
            return None, "Insufficient data for MACD."
        def ema(prices, period):
            multiplier = 2 / (period + 1)
            ema = [sum(prices[:period]) / period]
            for price in prices[period:]:
                ema.append((price * multiplier) + (ema[-1] * (1 - multiplier)))
            return ema
        ema_fast = ema(closes, fast)
        ema_slow = ema(closes, slow)
        macd = [f - s for f, s in zip(ema_fast[-len(ema_slow):], ema_slow)]
        signal_line = ema(macd, signal)
        ma_macd = [sum(macd[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(macd))]
        cross = "Bullish" if len(macd) >= 2 and macd[-2] < ma_macd[-2] and macd[-1] > ma_macd[-1] else "Bearish" if len(macd) >= 2 and macd[-2] > ma_macd[-2] and macd[-1] < ma_macd[-1] else "No Cross"
        return (macd, signal_line, ma_macd), f"MACD: {macd[-1]:.2f}, Signal: {signal_line[-1]:.2f}, MA({ma_period}): {ma_macd[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating MACD: {e}"
EOF
)"

# ADX Indicator (Scalping: period=7, MA=3)
create_file "$INDICATORS_DIR/adx.py" "$(cat << 'EOF'
import ccxt

def calculate_adx(exchange, symbol="BTCUSDT", timeframe="1m", period=7, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        if len(ohlcv) < period + ma_period + 1:
            return None, "Insufficient data for ADX."
        highs = [candle[2] for candle in ohlcv]
        lows = [candle[3] for candle in ohlcv]
        closes = [candle[4] for candle in ohlcv]
        plus_dm = [max(highs[i] - highs[i-1], 0) if highs[i] - highs[i-1] > lows[i-1] - lows[i] else 0 for i in range(1, len(highs))]
        minus_dm = [max(lows[i-1] - lows[i], 0) if lows[i-1] - lows[i] > highs[i] - highs[i-1] else 0 for i in range(1, len(lows))]
        tr = [max(highs[i] - lows[i], abs(highs[i] - closes[i-1]), abs(lows[i] - closes[i-1])) for i in range(1, len(highs))]
        def smooth(data, period):
            smoothed = [sum(data[:period]) / period]
            for i in range(period, len(data)):
                smoothed.append((smoothed[-1] * (period - 1) + data[i]) / period)
            return smoothed
        plus_di = [100 * p / t for p, t in zip(smooth(plus_dm, period), smooth(tr, period))]
        minus_di = [100 * m / t for m, t in zip(smooth(minus_dm, period), smooth(tr, period))]
        dx = [100 * abs(p - m) / (p + m) for p, m in zip(plus_di, minus_di)]
        adx = smooth(dx, period)
        ma_adx = [sum(adx[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(adx))]
        cross = "Bullish" if len(adx) >= 2 and adx[-2] < ma_adx[-2] and adx[-1] > ma_adx[-1] else "Bearish" if len(adx) >= 2 and adx[-2] > ma_adx[-2] and adx[-1] < ma_adx[-1] else "No Cross"
        return (adx, ma_adx), f"ADX({period}): {adx[-1]:.2f}, MA({ma_period}): {ma_adx[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating ADX: {e}"
EOF
)"

# PSAR Indicator (Scalping: af_start=0.02, MA=3)
create_file "$INDICATORS_DIR/psar.py" "$(cat << 'EOF'
import ccxt

def calculate_psar(exchange, symbol="BTCUSDT", timeframe="1m", af_start=0.02, af_max=0.2, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        if len(ohlcv) < ma_period + 2:
            return None, "Insufficient data for PSAR."
        highs = [candle[2] for candle in ohlcv]
        lows = [candle[3] for candle in ohlcv]
        psar = [lows[0]]
        ep = highs[0]
        af = af_start
        trend = 1
        for i in range(1, len(highs)):
            prev_psar = psar[-1]
            if trend == 1:
                psar.append(prev_psar + af * (ep - prev_psar))
                if lows[i] < psar[-1]:
                    trend = -1
                    psar[-1] = ep
                    ep = lows[i]
                    af = af_start
                elif highs[i] > ep:
                    ep = highs[i]
                    af = min(af + af_start, af_max)
            else:
                psar.append(prev_psar - af * (prev_psar - ep))
                if highs[i] > psar[-1]:
                    trend = 1
                    psar[-1] = ep
                    ep = highs[i]
                    af = af_start
                elif lows[i] < ep:
                    ep = lows[i]
                    af = min(af + af_start, af_max)
        ma_psar = [sum(psar[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(psar))]
        cross = "Bullish" if len(psar) >= 2 and psar[-2] < ma_psar[-2] and psar[-1] > ma_psar[-1] else "Bearish" if len(psar) >= 2 and psar[-2] > ma_psar[-2] and psar[-1] < ma_psar[-1] else "No Cross"
        return (psar, ma_psar), f"PSAR: {psar[-1]:.2f}, MA({ma_period}): {ma_psar[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating PSAR: {e}"
EOF
)"

# Ichimoku Indicator (Scalping: tenkan=5, kijun=13, senkou=26, MA=3)
create_file "$INDICATORS_DIR/ichimoku.py" "$(cat << 'EOF'
import ccxt

def calculate_ichimoku(exchange, symbol="BTCUSDT", timeframe="1m", tenkan=5, kijun=13, senkou=26, ma_period=3, limit=100):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        if len(ohlcv) < senkou + ma_period:
            return None, "Insufficient data for Ichimoku."
        highs = [candle[2] for candle in ohlcv]
        lows = [candle[3] for candle in ohlcv]
        tenkan_sen = [(max(highs[i-tenkan+1:i+1]) + min(lows[i-tenkan+1:i+1])) / 2 if i >= tenkan-1 else 0 for i in range(len(highs))]
        kijun_sen = [(max(highs[i-kijun+1:i+1]) + min(lows[i-kijun+1:i+1])) / 2 if i >= kijun-1 else 0 for i in range(len(highs))]
        senkou_span_a = [(t + k) / 2 for t, k in zip(tenkan_sen, kijun_sen)]
        ma_span_a = [sum(senkou_span_a[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(senkou_span_a))]
        cross = "Bullish" if len(senkou_span_a) >= 2 and senkou_span_a[-2] < ma_span_a[-2] and senkou_span_a[-1] > ma_span_a[-1] else "Bearish" if len(senkou_span_a) >= 2 and senkou_span_a[-2] > ma_span_a[-2] and senkou_span_a[-1] < ma_span_a[-1] else "No Cross"
        return (tenkan_sen, kijun_sen, senkou_span_a), f"Span A: {senkou_span_a[-1]:.2f}, MA({ma_period}): {ma_span_a[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating Ichimoku: {e}"
EOF
)"

# Bollinger Bands Indicator (Scalping: period=10, MA=3)
create_file "$INDICATORS_DIR/bollinger.py" "$(cat << 'EOF'
import ccxt
import statistics

def calculate_bollinger(exchange, symbol="BTCUSDT", timeframe="1m", period=10, dev=2, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < period + ma_period:
            return None, "Insufficient data for Bollinger Bands."
        sma = []
        upper = []
        lower = []
        for i in range(period - 1, len(closes)):
            window = closes[i - period + 1:i + 1]
            sma_val = sum(window) / period
            std_dev = statistics.stdev(window)
            sma.append(sma_val)
            upper.append(sma_val + dev * std_dev)
            lower.append(sma_val - dev * std_dev)
        ma_sma = [sum(sma[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(sma))]
        cross = "Bullish" if len(sma) >= 2 and sma[-2] < ma_sma[-2] and sma[-1] > ma_sma[-1] else "Bearish" if len(sma) >= 2 and sma[-2] > ma_sma[-2] and sma[-1] < ma_sma[-1] else "No Cross"
        return (sma, upper, lower, ma_sma), f"Middle: {sma[-1]:.2f}, MA({ma_period}): {ma_sma[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating Bollinger Bands: {e}"
EOF
)"

# RSI Indicator (Scalping: period=7, MA=3)
create_file "$INDICATORS_DIR/rsi.py" "$(cat << 'EOF'
import ccxt

def calculate_rsi(exchange, symbol="BTCUSDT", timeframe="1m", period=7, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < period + ma_period + 1:
            return None, "Insufficient data for RSI."
        gains = [max(closes[i] - closes[i-1], 0) for i in range(1, len(closes))]
        losses = [max(closes[i-1] - closes[i], 0) for i in range(1, len(closes))]
        avg_gain = sum(gains[:period]) / period
        avg_loss = sum(losses[:period]) / period
        rsi = []
        for i in range(period, len(gains)):
            avg_gain = (avg_gain * (period - 1) + gains[i]) / period
            avg_loss = (avg_loss * (period - 1) + losses[i]) / period
            rs = avg_gain / avg_loss if avg_loss != 0 else float('inf')
            rsi.append(100 - (100 / (1 + rs)))
        ma_rsi = [sum(rsi[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(rsi))]
        cross = "Bullish" if len(rsi) >= 2 and rsi[-2] < ma_rsi[-2] and rsi[-1] > ma_rsi[-1] else "Bearish" if len(rsi) >= 2 and rsi[-2] > ma_rsi[-2] and rsi[-1] < ma_rsi[-1] else "No Cross"
        return (rsi, ma_rsi), f"RSI({period}): {rsi[-1]:.2f}, MA({ma_period}): {ma_rsi[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating RSI: {e}"
EOF
)"

# Stochastic RSI Indicator (Scalping: period=7, k_period=7, d_period=3, MA=3)
create_file "$INDICATORS_DIR/stoch_rsi.py" "$(cat << 'EOF'
import ccxt

def calculate_stoch_rsi(exchange, symbol="BTCUSDT", timeframe="1m", period=7, k_period=7, d_period=3, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < period + k_period + d_period + ma_period:
            return None, "Insufficient data for Stoch RSI."
        gains = [max(closes[i] - closes[i-1], 0) for i in range(1, len(closes))]
        losses = [max(closes[i-1] - closes[i], 0) for i in range(1, len(closes))]
        avg_gain = sum(gains[:period]) / period
        avg_loss = sum(losses[:period]) / period
        rsi = []
        for i in range(period, len(gains)):
            avg_gain = (avg_gain * (period - 1) + gains[i]) / period
            avg_loss = (avg_loss * (period - 1) + losses[i]) / period
            rs = avg_gain / avg_loss if avg_loss != 0 else float('inf')
            rsi.append(100 - (100 / (1 + rs)))
        stoch_rsi = []
        for i in range(k_period - 1, len(rsi)):
            rsi_window = rsi[i - k_period + 1:i + 1]
            lowest = min(rsi_window)
            highest = max(rsi_window)
            k = 100 * (rsi[i] - lowest) / (highest - lowest) if highest != lowest else (100 if rsi[i] == highest else 0)
            stoch_rsi.append(k)
        ma_stoch = [sum(stoch_rsi[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(stoch_rsi))]
        cross = "Bullish" if len(stoch_rsi) >= 2 and stoch_rsi[-2] < ma_stoch[-2] and stoch_rsi[-1] > ma_stoch[-1] else "Bearish" if len(stoch_rsi) >= 2 and stoch_rsi[-2] > ma_stoch[-2] and stoch_rsi[-1] < ma_stoch[-1] else "No Cross"
        return (stoch_rsi, ma_stoch), f"Stoch RSI K: {stoch_rsi[-1]:.2f}, MA({ma_period}): {ma_stoch[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating Stoch RSI: {e}"
EOF
)"

# Momentum Indicator (Scalping: period=5, MA=3)
create_file "$INDICATORS_DIR/momentum.py" "$(cat << 'EOF'
import ccxt

def calculate_momentum(exchange, symbol="BTCUSDT", timeframe="1m", period=5, ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < period + ma_period + 1:
            return None, "Insufficient data for Momentum."
        momentum = [closes[i] - closes[i - period] for i in range(period, len(closes))]
        ma_momentum = [sum(momentum[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(momentum))]
        cross = "Bullish" if len(momentum) >= 2 and momentum[-2] < ma_momentum[-2] and momentum[-1] > ma_momentum[-1] else "Bearish" if len(momentum) >= 2 and momentum[-2] > ma_momentum[-2] and momentum[-1] < ma_momentum[-1] else "No Cross"
        return (momentum, ma_momentum), f"Momentum({period}): {momentum[-1]:.2f}, MA({ma_period}): {ma_momentum[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating Momentum: {e}"
EOF
)"

# MA Momentum Indicator (Scalping: mom_period=5, ma_period=3, trigger MA=3)
create_file "$INDICATORS_DIR/ma_momentum.py" "$(cat << 'EOF'
import ccxt

def calculate_ma_momentum(exchange, symbol="BTCUSDT", timeframe="1m", mom_period=5, ma_period=3, trigger_ma=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < mom_period + ma_period + trigger_ma:
            return None, "Insufficient data for MA Momentum."
        momentum = [closes[i] - closes[i - mom_period] for i in range(mom_period, len(closes))]
        ma_momentum = [sum(momentum[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(momentum))]
        trigger_ma_mom = [sum(ma_momentum[i - trigger_ma + 1:i + 1]) / trigger_ma for i in range(trigger_ma - 1, len(ma_momentum))]
        cross = "Bullish" if len(ma_momentum) >= 2 and ma_momentum[-2] < trigger_ma_mom[-2] and ma_momentum[-1] > trigger_ma_mom[-1] else "Bearish" if len(ma_momentum) >= 2 and ma_momentum[-2] > trigger_ma_mom[-2] and ma_momentum[-1] < trigger_ma_mom[-1] else "No Cross"
        return (momentum, ma_momentum, trigger_ma_mom), f"MA Momentum({mom_period}, {ma_period}): {ma_momentum[-1]:.2f}, Trigger MA({trigger_ma}): {trigger_ma_mom[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating MA Momentum: {e}"
EOF
)"

# VWAP Indicator (Scalping: resets daily, MA=3)
create_file "$INDICATORS_DIR/vwap.py" "$(cat << 'EOF'
import ccxt

def calculate_vwap(exchange, symbol="BTCUSDT", timeframe="1m", ma_period=3, limit=1440):  # 1440 minutes = 1 day
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        if len(ohlcv) < ma_period + 1:
            return None, "Insufficient data for VWAP."
        typical_prices = [(candle[2] + candle[3] + candle[4]) / 3 for candle in ohlcv]
        volumes = [candle[5] for candle in ohlcv]
        vwap = []
        cum_price_vol = 0
        cum_vol = 0
        for i in range(len(typical_prices)):
            cum_price_vol += typical_prices[i] * volumes[i]
            cum_vol += volumes[i]
            vwap.append(cum_price_vol / cum_vol if cum_vol != 0 else 0)
        ma_vwap = [sum(vwap[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(vwap))]
        cross = "Bullish" if len(vwap) >= 2 and vwap[-2] < ma_vwap[-2] and vwap[-1] > ma_vwap[-1] else "Bearish" if len(vwap) >= 2 and vwap[-2] > ma_vwap[-2] and vwap[-1] < ma_vwap[-1] else "No Cross"
        return (vwap, ma_vwap), f"VWAP: {vwap[-1]:.2f}, MA({ma_period}): {ma_vwap[-1]:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating VWAP: {e}"
EOF
)"

# Fibonacci Moving Averages (Scalping: periods=[5, 8, 13], MA=3)
create_file "$INDICATORS_DIR/fibonacci_ma.py" "$(cat << 'EOF'
import ccxt

def calculate_fibonacci_ma(exchange, symbol="BTCUSDT", timeframe="1m", fib_periods=[5, 8, 13], ma_period=3, limit=50):
    try:
        ohlcv = exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
        closes = [candle[4] for candle in ohlcv]
        if len(closes) < max(fib_periods) + ma_period:
            return None, "Insufficient data for Fibonacci MA."
        fib_mas = {}
        ma_fib_mas = {}
        for period in fib_periods:
            sma = [sum(closes[i - period + 1:i + 1]) / period for i in range(period - 1, len(closes))]
            fib_mas[period] = sma
            ma_fib_mas[period] = [sum(sma[i - ma_period + 1:i + 1]) / ma_period for i in range(ma_period - 1, len(sma))]
        latest_fib = fib_mas[max(fib_periods)][-1]
        latest_ma = ma_fib_mas[max(fib_periods)][-1]
        cross = "Bullish" if len(fib_mas[max(fib_periods)]) >= 2 and fib_mas[max(fib_periods)][-2] < ma_fib_mas[max(fib_periods)][-2] and latest_fib > latest_ma else "Bearish" if len(fib_mas[max(fib_periods)]) >= 2 and fib_mas[max(fib_periods)][-2] > ma_fib_mas[max(fib_periods)][-2] and latest_fib < latest_ma else "No Cross"
        return (fib_mas, ma_fib_mas), f"Fib MA({max(fib_periods)}): {latest_fib:.2f}, MA({ma_period}): {latest_ma:.2f}, {cross}"
    except Exception as e:
        return None, f"Error calculating Fibonacci MA: {e}"
EOF
)"

# Strategies Directory: Placeholder for Scalping Strategies
create_file "$STRATEGIES_DIR/orderbook_stoch.py" "$(cat << 'EOF'
def orderbook_stoch_strategy
