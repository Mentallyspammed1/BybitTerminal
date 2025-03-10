#!/usr/bin/env python3
import ccxt.async_support as ccxt_async
import os
import time
import curses
import asyncio
from pybit.unified_trading import AsyncHTTP
from indicators.sma import calculate_sma
from indicators.ema import calculate_ema
from indicators.macd import calculate_macd
from indicators.adx import calculate_adx
from indicators.psar import calculate_psar
from indicators.ichimoku import calculate_ichimoku
from indicators.bollinger import calculate_bollinger
from indicators.rsi import calculate_rsi
from indicators.stoch_rsi import calculate_stoch_rsi
from indicators.momentum import calculate_momentum
from indicators.ma_momentum import calculate_ma_momentum
from indicators.vwap import calculate_vwap
from indicators.fibonacci_ma import calculate_fibonacci_ma
from strategies.orderbook_stoch import orderbook_stoch_strategy
from strategies.fibonacci_bounce import fibonacci_bounce_strategy
from strategies.stoch_fib_breakout import stoch_fib_breakout_strategy
from strategies.risk_management import calculate_position_size
from strategies.trade_logger import log_trade

# Initialize asynchronous ccxt for real-time calls
exchange_async = ccxt_async.bybit({
    'apiKey': os.getenv("BYBIT_API_KEY"),
    'secret': os.getenv("BYBIT_API_SECRET"),
    'enableRateLimit': True,
    'options': {'defaultType': 'future'},
    'rateLimit': 200  # Adjust if needed
})

# Initialize asynchronous pybit session for trading actions
pybit_session = AsyncHTTP(api_key=os.getenv("BYBIT_API_KEY"), api_secret=os.getenv("BYBIT_API_SECRET"))

# Mystical elements
MYSTICAL_BORDER = "✨ ~~~ "

# Status state for real-time data and animations
status_state = {
    'current_price': None,
    'prev_price': None,
    'bid': None,
    'ask': None,
    'spinner_index': 0,
    'last_spinner_update': time.time(),
    'symbol': 'BTCUSDT'
}

async def websocket_ticker(exchange, status_state, status_win):
    """Fetch real-time ticker data via WebSocket."""
    symbol = status_state['symbol']
    while True:
        try:
            ticker = await exchange.watch_ticker(symbol)
            status_state['prev_price'] = status_state['current_price']
            status_state['current_price'] = ticker['last']
            status_state['bid'] = ticker['bid']
            status_state['ask'] = ticker['ask']
            update_status_line(status_win, status_state)
        except Exception as e:
            status_win.clear()
            status_win.addstr(0, 0, f"WebSocket Error: {e}", curses.color_pair(2))
            status_win.refresh()
            await asyncio.sleep(1)
        # Check if the symbol has changed; if so, restart the connection.
        if status_state['symbol'] != symbol:
            symbol = status_state['symbol']
            await exchange.close()  # Close old connection
            await exchange.load_markets()  # Reinitialize markets

def update_status_line(status_win, status_state):
    """Update the status line with real-time data and spinner."""
    current_time = time.time()
    if current_time - status_state['last_spinner_update'] >= 0.2:
        status_state['spinner_index'] = (status_state['spinner_index'] + 1) % 4
        status_state['last_spinner_update'] = current_time

    price_str = f"{status_state['current_price']:.2f}" if status_state['current_price'] else "N/A"
    bid_str = f"{status_state['bid']:.2f}" if status_state['bid'] else "N/A"
    ask_str = f"{status_state['ask']:.2f}" if status_state['ask'] else "N/A"
    color = 1 if status_state['prev_price'] is None or status_state['current_price'] == status_state['prev_price'] else 3 if status_state['current_price'] > status_state['prev_price'] else 2
    spinner = ['|', '/', '-', '\\'][status_state['spinner_index']]
    
    status_win.clear()
    status_win.addstr(0, 0, f"{status_state['symbol']} Price: {price_str}  Bid: {bid_str}  Ask: {ask_str} {spinner}", curses.color_pair(color))
    status_win.refresh()

async def get_account_info():
    """Fetch account balance information."""
    try:
        res = await pybit_session.get_wallet_balance(accountType="UNIFIED")
        balance = res['result']['list'][0]['totalEquity']
        return f"Total Equity: {balance}"
    except Exception as e:
        return f"Error fetching account info: {e}"

async def get_positions():
    """Fetch current open positions."""
    try:
        res = await pybit_session.get_positions(category="linear", symbol="BTCUSDT")
        positions = res['result']['list']
        return "\n".join([f"{p['symbol']}: {p['size']} ({p['side']})" for p in positions]) if positions else "No positions."
    except Exception as e:
        return f"Error fetching positions: {e}"

async def calculate_fibonacci_pivots(exchange, symbol, timeframe):
    """Calculate Fibonacci pivot levels."""
    ohlcv = await exchange.fetch_ohlcv(symbol, timeframe, limit=2)
    prev_high, prev_low, prev_close = ohlcv[-2][2], ohlcv[-2][3], ohlcv[-2][4]
    pp = (prev_high + prev_low + prev_close) / 3
    range_ = prev_high - prev_low
    r1, r2 = pp + range_ * 0.382, pp + range_ * 0.618
    s1, s2 = pp - range_ * 0.382, pp - range_ * 0.618
    return f"PP: {pp:.2f}, R1: {r1:.2f}, R2: {r2:.2f}, S1: {s1:.2f}, S2: {s2:.2f}"

async def analyze_volume(exchange, symbol, timeframe):
    """Analyze volume trends."""
    ohlcv = await exchange.fetch_ohlcv(symbol, timeframe, limit=50)
    volumes = [candle[5] for candle in ohlcv]
    total_volume = sum(volumes)
    avg_volume = total_volume / len(volumes)
    volume_change = ((volumes[-1] - volumes[-2]) / volumes[-2] * 100) if volumes[-2] != 0 else 0
    return f"Total Volume: {total_volume:.2f}, Avg: {avg_volume:.2f}, Change: {volume_change:.2f}%"

async def analyze_order_book(exchange, symbol, limit=20):
    """Analyze order book depth."""
    ob = await exchange.fetch_order_book(symbol, limit)
    bids, asks = ob['bids'], ob['asks']
    bid_volume = sum(amount for _, amount in bids)
    ask_volume = sum(amount for _, amount in asks)
    imbalance = (bid_volume - ask_volume) / (bid_volume + ask_volume) * 100 if bid_volume + ask_volume != 0 else 0
    return f"Top Bid: {bids[0][0]:.2f}, Top Ask: {asks[0][0]:.2f}, Imbalance: {imbalance:.2f}%"

async def trading_interface(stdscr, menu_win, status_win, status_state, exchange):
    """Trading interface with real-time price integration."""
    menu_win.clear()
    menu_win.addstr(0, 0, "Enter symbol (e.g., BTCUSDT): ", curses.color_pair(1))
    menu_win.refresh()
    symbol = menu_win.getstr(0, 30, 10).decode().upper()
    status_state['symbol'] = symbol
    while True:
        update_status_line(status_win, status_state)  # Keep UI updated
        menu_win.clear()
        menu_win.addstr(0, 0, f"{MYSTICAL_BORDER}Trading Interface - {symbol}{MYSTICAL_BORDER}", curses.color_pair(2))
        menu_win.addstr(2, 0, "1. Place Limit Order", curses.color_pair(4))
        menu_win.addstr(3, 0, "2. Place Market Order", curses.color_pair(4))
        menu_win.addstr(4, 0, "3. Set Stop-Loss/Take-Profit", curses.color_pair(4))
        menu_win.addstr(5, 0, "4. Cancel Order", curses.color_pair(4))
        menu_win.addstr(6, 0, "5. Close Position", curses.color_pair(4))
        menu_win.addstr(7, 0, "6. Back to Main", curses.color_pair(4))
        menu_win.addstr(9, 0, "Enter choice: ", curses.color_pair(1))
        menu_win.refresh()
        choice = menu_win.getstr(9, 13, 20).decode().strip()
        if choice == "1":
            menu_win.addstr(11, 0, "Side (Buy/Sell): ", curses.color_pair(1))
            menu_win.refresh()
            side = menu_win.getstr(11, 17, 10).decode().lower()
            menu_win.addstr(12, 0, "Quantity: ", curses.color_pair(1))
            menu_win.refresh()
            qty = float(menu_win.getstr(12, 10, 10).decode())
            menu_win.addstr(13, 0, "Price: ", curses.color_pair(1))
            menu_win.refresh()
            price = float(menu_win.getstr(13, 7, 10).decode())
            try:
                order = await pybit_session.place_order(symbol=symbol, side=side.capitalize(), order_type="Limit", qty=qty, price=price, time_in_force="GTC")
                log_trade(symbol, side, qty, price, order['result']['orderId'])
                menu_win.addstr(15, 0, f"Order ID: {order['result']['orderId']}", curses.color_pair(3))
            except Exception as e:
                menu_win.addstr(15, 0, f"Order failed: {e}", curses.color_pair(2))
        elif choice == "2":
            menu_win.addstr(11, 0, "Side (Buy/Sell): ", curses.color_pair(1))
            menu_win.refresh()
            side = menu_win.getstr(11, 17, 10).decode().lower()
            menu_win.addstr(12, 0, "Quantity: ", curses.color_pair(1))
            menu_win.refresh()
            qty = float(menu_win.getstr(12, 10, 10).decode())
            try:
                order = await pybit_session.place_order(symbol=symbol, side=side.capitalize(), order_type="Market", qty=qty)
                log_trade(symbol, side, qty, status_state['current_price'], order['result']['orderId'])
                menu_win.addstr(14, 0, f"Order ID: {order['result']['orderId']}", curses.color_pair(3))
            except Exception as e:
                menu_win.addstr(14, 0, f"Order failed: {e}", curses.color_pair(2))
        elif choice == "3":
            menu_win.addstr(11, 0, "Side (Buy/Sell): ", curses.color_pair(1))
            menu_win.refresh()
            side = menu_win.getstr(11, 17, 10).decode().lower()
            menu_win.addstr(12, 0, "Quantity: ", curses.color_pair(1))
            menu_win.refresh()
            qty = float(menu_win.getstr(12, 10, 10).decode())
            menu_win.addstr(13, 0, "Price: ", curses.color_pair(1))
            menu_win.refresh()
            price = float(menu_win.getstr(13, 7, 10).decode())
            menu_win.addstr(14, 0, "Stop-Loss: ", curses.color_pair(1))
            menu_win.refresh()
            sl = float(menu_win.getstr(14, 11, 10).decode())
            menu_win.addstr(15, 0, "Take-Profit: ", curses.color_pair(1))
            menu_win.refresh()
            tp = float(menu_win.getstr(15, 13, 10).decode())
            try:
                order = await pybit_session.place_order(symbol=symbol, side=side.capitalize(), order_type="Limit", qty=qty, price=price, stop_loss=sl, take_profit=tp, time_in_force="GTC")
                log_trade(symbol, side, qty, price, order['result']['orderId'])
                menu_win.addstr(17, 0, f"Order ID: {order['result']['orderId']}", curses.color_pair(3))
            except Exception as e:
                menu_win.addstr(17, 0, f"Order failed: {e}", curses.color_pair(2))
        elif choice == "4":
            menu_win.addstr(11, 0, "Order ID: ", curses.color_pair(1))
            menu_win.refresh()
            order_id = menu_win.getstr(11, 10, 20).decode()
            try:
                await pybit_session.cancel_order(symbol=symbol, order_id=order_id)
                menu_win.addstr(13, 0, "Order cancelled", curses.color_pair(3))
            except Exception as e:
                menu_win.addstr(13, 0, f"Cancel failed: {e}", curses.color_pair(2))
        elif choice == "5":
            menu_win.addstr(11, 0, "Side to close (Buy/Sell): ", curses.color_pair(1))
            menu_win.refresh()
            side = menu_win.getstr(11, 26, 10).decode().lower()
            menu_win.addstr(12, 0, "Quantity: ", curses.color_pair(1))
            menu_win.refresh()
            qty = float(menu_win.getstr(12, 10, 10).decode())
            try:
                order = await pybit_session.place_order(symbol=symbol, side=("Sell" if side == "buy" else "Buy"), order_type="Market", qty=qty)
                log_trade(symbol, "Sell" if side == "buy" else "Buy", qty, status_state['current_price'], order['result']['orderId'])
                menu_win.addstr(14, 0, f"Position closed - ID: {order['result']['orderId']}", curses.color_pair(3))
            except Exception as e:
                menu_win.addstr(14, 0, f"Close position failed: {e}", curses.color_pair(2))
        elif choice == "6":
            break
        menu_win.addstr(19, 0, "Press any key to continue", curses.color_pair(4))
        menu_win.refresh()
        menu_win.getch()

async def main(stdscr):
    """Main async function for the trading terminal."""
    curses.curs_set(0)
    stdscr.nodelay(True)
    stdscr.timeout(100)
    if not curses.has_colors():
        raise Exception("Terminal does not support colors.")
    curses.start_color()
    curses.init_pair(1, curses.COLOR_CYAN, curses.COLOR_BLACK)    # Cyan
    curses.init_pair(2, curses.COLOR_MAGENTA, curses.COLOR_BLACK) # Magenta
    curses.init_pair(3, curses.COLOR_GREEN, curses.COLOR_BLACK)   # Green
    curses.init_pair(4, curses.COLOR_YELLOW, curses.COLOR_BLACK)  # Yellow
    rows, cols = stdscr.getmaxyx()
    menu_win = stdscr.subwin(rows - 1, cols, 0, 0)
    status_win = stdscr.subwin(1, cols, rows - 1, 0)

    # Initialize async exchange for WebSocket
    exchange = ccxt_async.bybit({
        'apiKey': os.getenv("BYBIT_API_KEY"),
        'secret': os.getenv("BYBIT_API_SECRET"),
        'enableRateLimit': True,
        'options': {'defaultType': 'future'},
        'rateLimit': 200
    })
    await exchange.load_markets()

    # Start WebSocket ticker task
    asyncio.create_task(websocket_ticker(exchange, status_state, status_win))

    while True:
        menu_win.clear()
        menu_win.addstr(0, 0, f"{MYSTICAL_BORDER}Bybit Terminal - Cosmic Nexus{MYSTICAL_BORDER}", curses.color_pair(2))
        menu_win.addstr(2, 0, "1. Account Info", curses.color_pair(4))
        menu_win.addstr(3, 0, "2. Positions", curses.color_pair(4))
        menu_win.addstr(4, 0, "3. Order Book", curses.color_pair(4))
        menu_win.addstr(5, 0, "4. Trading Interface", curses.color_pair(4))
        menu_win.addstr(6, 0, "5. Fibonacci Pivots", curses.color_pair(4))
        menu_win.addstr(7, 0, "6. Trend Indicators", curses.color_pair(4))
        menu_win.addstr(8, 0, "7. Volume & Order Book Analysis", curses.color_pair(4))
        menu_win.addstr(9, 0, "8. Scalping Strategies", curses.color_pair(4))
        menu_win.addstr(10, 0, "9. Exit", curses.color_pair(4))
        menu_win.addstr(12, 0, "Enter choice: ", curses.color_pair(1))
        menu_win.refresh()
        choice = menu_win.getstr(12, 13, 20).decode().strip()

        if choice == "1":
            menu_win.clear()
            info = await get_account_info()
            menu_win.addstr(0, 0, info, curses.color_pair(1))
            menu_win.addstr(2, 0, "Press any key", curses.color_pair(4))
            menu_win.refresh()
            menu_win.getch()
        elif choice == "2":
            menu_win.clear()
            positions = await get_positions()
            menu_win.addstr(0, 0, positions, curses.color_pair(1))
            menu_win.addstr(2, 0, "Press any key", curses.color_pair(4))
            menu_win.refresh()
            menu_win.getch()
        elif choice == "3":
            menu_win.clear()
            menu_win.addstr(0, 0, "Symbol: ", curses.color_pair(1))
            menu_win.refresh()
            symbol = menu_win.getstr(0, 8, 10).decode().upper()
            analysis = await analyze_order_book(exchange, symbol)
            menu_win.addstr(2, 0, analysis, curses.color_pair(1))
            menu_win.addstr(4, 0, "Press any key", curses.color_pair(4))
            menu_win.refresh()
            menu_win.getch()
        elif choice == "4":
            await trading_interface(stdscr, menu_win, status_win, status_state, exchange)
        elif choice == "5":
            menu_win.clear()
            menu_win.addstr(0, 0, "Symbol: ", curses.color_pair(1))
            menu_win.refresh()
            symbol = menu_win.getstr(0, 8, 10).decode().upper()
            menu_win.addstr(1, 0, "Timeframe: ", curses.color_pair(1))
            menu_win.refresh()
            timeframe = menu_win.getstr(1, 11, 10).decode()
            pivots = await calculate_fibonacci_pivots(exchange, symbol, timeframe)
            menu_win.addstr(3, 0, pivots, curses.color_pair(1))
            menu_win.addstr(5, 0, "Press any key", curses.color_pair(4))
            menu_win.refresh()
            menu_win.getch()
        elif choice == "6":
            menu_win.clear()
            menu_win.addstr(0, 0, "Symbol: ", curses.color_pair(1))
            menu_win.refresh()
            symbol = menu_win.getstr(0, 8, 10).decode().upper()
            menu_win.addstr(1, 0, "Timeframe: ", curses.color_pair(1))
            menu_win.refresh()
            timeframe = menu_win.getstr(1, 11, 10).decode()
            menu_win.addstr(3, 0, "1. SMA 2. EMA 3. MACD 4. ADX 5. PSAR 6. Ichimoku 7. Bollinger 8. RSI 9. Stoch RSI 10. Momentum 11. MA Momentum 12. VWAP 13. Fib MA", curses.color_pair(4))
            menu_win.addstr(4, 0, "Choice: ", curses.color_pair(1))
            menu_win.refresh()
            ind_choice = menu_win.getstr(4, 8, 10).decode()
            _, msg = {
                "1": calculate_sma, "2": calculate_ema, "3": calculate_macd, "4": calculate_adx,
                "5": calculate_psar, "6": calculate_ichimoku, "7": calculate_bollinger, "8": calculate_rsi,
                "9": calculate_stoch_rsi, "10": calculate_momentum, "11": calculate_ma_momentum,
                "12": calculate_vwap, "13": calculate_fibonacci_ma
            }.get(ind_choice, lambda *args: (None, "Invalid choice"))(exchange, symbol, timeframe)
            menu_win.addstr(6, 0, msg, curses.color_pair(1))
            menu_win.addstr(8, 0, "Press any key", curses.color_pair(4))
            menu_win.refresh()
            menu_win.getch()
        elif choice == "7":
            menu_win.clear()
            menu_win.addstr(0, 0, "Symbol: ", curses.color_pair(1))
            menu_win.refresh()
            symbol = menu_win.getstr(0, 8, 10).decode().upper()
            menu_win.addstr(1, 0, "1. Volume 2. Order Book", curses.color_pair(4))
            menu_win.addstr(2, 0, "Choice: ", curses.color_pair(1))
            menu_win.refresh()
            analysis_choice = menu_win.getstr(2, 8, 10).decode()
            if analysis_choice == "1":
                menu_win.addstr(3, 0, "Timeframe: ", curses.color_pair(1))
                menu_win.refresh()
                timeframe = menu_win.getstr(3, 11, 10).decode()
                vol_analysis = await analyze_volume(exchange, symbol, timeframe)
                menu_win.addstr(5, 0, vol_analysis, curses.color_pair(1))
            elif analysis_choice == "2":
                analysis = await analyze_order_book(exchange, symbol)
                menu_win.addstr(3, 0, analysis, curses.color_pair(1))
            menu_win.addstr(7, 0, "Press any key", curses.color_pair(4))
            menu_win.refresh()
            menu_win.getch()
        elif choice == "8":
            menu_win.clear()
            menu_win.addstr(0, 0, "Symbol: ", curses.color_pair(1))
            menu_win.refresh()
            symbol = menu_win.getstr(0, 8, 10).decode().upper()
            menu_win.addstr(1, 0, "Timeframe: ", curses.color_pair(1))
            menu_win.refresh()
            timeframe = menu_win.getstr(1, 11, 10).decode()
            menu_win.addstr(3, 0, "1. Order Book + Stoch RSI 2. Fibonacci Bounce 3. Stoch RSI + Fib Breakout", curses.color_pair(4))
            menu_win.addstr(4, 0, "Choice: ", curses.color_pair(1))
            menu_win.refresh()
            strat_choice = menu_win.getstr(4, 8, 10).decode()
            msg = {
                "1": orderbook_stoch_strategy, "2": fibonacci_bounce_strategy, "3": stoch_fib_breakout_strategy
            }.get(strat_choice, lambda *args: "Invalid choice")(exchange, symbol, timeframe)
            menu_win.addstr(6, 0, msg, curses.color_pair(1))
            menu_win.addstr(8, 0, "Press any key", curses.color_pair(4))
            menu_win.refresh()
            menu_win.getch()
        elif choice == "9":
            await exchange.close()
            break
        await asyncio.sleep(0.1)  # Allow WebSocket updates

if __name__ == "__main__":
    asyncio.run(curses.wrapper(main))
