#!/bin/bash

# ------------------------------------------------------------------
# WARNING: BEFORE RUNNING THIS SCRIPT:
#
# 1. REPLACE "YOUR_BYBIT_API_KEY_HERE" and "YOUR_BYBIT_SECRET_KEY_HERE"
#    in the `echo` commands below with your ACTUAL Bybit API keys.
# 2. Understand that hardcoding API keys (even in ~/.bashrc) is
#    less secure than using more robust methods for production.
#    This script is for simplified setup in Termux for demonstration.
# ------------------------------------------------------------------

# Define enhanced neon color palette
NEON_PURPLE='\033[95m'    # Bright Magenta/Purple
NEON_CYAN='\033[96m'      # Bright Cyan
NEON_LIME='\033[92m'      # Bright Lime Green
NEON_ORANGE='\033[93m'    # Bright Orange
NEON_PINK='\033[91m'      # Bright Pink/Red
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${NEON_PURPLE}${BOLD}--------------------------------------------------${RESET}"
echo -e "${NEON_LIME}${BOLD} Setting up Neon Bybit Terminal Viewer with All Order Types ${RESET}"
echo -e "${NEON_PURPLE}${BOLD}--------------------------------------------------${RESET}"

# Step 1: Create app.py (Flask backend with all order types)
echo -e "\n${NEON_CYAN}[1/6] Creating app.py (Flask backend with all order types)...${RESET}"
cat > app.py << EOF
from flask import Flask, jsonify, request
import ccxt
import os

app = Flask(__name__)

# ANSI color codes for enhanced neon effects
COLORS = {
    'reset': '\033[0m',
    'neon_lime': '\033[92m',    # Bright Lime Green
    'neon_cyan': '\033[96m',    # Bright Cyan
    'neon_purple': '\033[95m',  # Bright Purple
    'neon_orange': '\033[93m',  # Bright Orange
    'neon_pink': '\033[91m',    # Bright Pink
    'bold': '\033[1m',
    'underline': '\033[4m',
}

def colorize(text, color_name):
    """Applies ANSI color codes to text."""
    return COLORS.get(color_name, COLORS['reset']) + text + COLORS['reset']

# Initialize Bybit exchange with API keys from environment variables
bybit = ccxt.bybit({
    'apiKey': os.environ.get('BYBIT_API_KEY'),
    'secret': os.environ.get('BYBIT_SECRET_KEY'),
})

@app.route('/')
def main_menu():
    menu_text = colorize(COLORS['bold'] + COLORS['neon_purple'] + "  ** Neon Bybit Terminal Viewer **  " + COLORS['reset'] + "\n", 'neon_purple')
    menu_text += colorize(COLORS['neon_cyan'] + "Choose an option:\n" + COLORS['reset'], 'neon_cyan')
    menu_text += colorize(COLORS['neon_orange'] + "1. Account Balance\n" + COLORS['reset'], 'neon_orange')
    menu_text += colorize(COLORS['neon_orange'] + "2. Open Orders\n" + COLORS['reset'], 'neon_orange')
    menu_text += colorize(COLORS['neon_orange'] + "3. Recent Trades\n" + COLORS['reset'], 'neon_orange')
    menu_text += colorize(COLORS['neon_orange'] + "4. Place Order (Market/Limit/Stop-Loss/Take-Profit)\n" + COLORS['reset'], 'neon_orange')
    menu_text += colorize(COLORS['neon_orange'] + "5. Cancel Order\n" + COLORS['reset'], 'neon_orange')
    menu_text += colorize(COLORS['neon_orange'] + "6. Exit\n" + COLORS['reset'], 'neon_orange')
    menu_text += colorize(COLORS['neon_cyan'] + "\nEnter your choice (1-6): " + COLORS['reset'], 'neon_cyan')
    return menu_text, 200, {'Content-Type': 'text/plain'}

@app.route('/account_balance')
def get_account_balance_terminal():
    try:
        balance = bybit.fetch_balance()
        formatted_balance = colorize(COLORS['bold'] + COLORS['neon_lime'] + "** Account Balance **\n" + COLORS['reset'], 'neon_lime')
        for coin, data in balance.items():
            if isinstance(data, dict) and 'total' in data and data['total'] > 0:
                formatted_balance += colorize(f"{COLORS['neon_orange']}{coin}: {COLORS['neon_cyan']}Total: {data['total']}, Free: {data['free']}, Used: {data['used']}{COLORS['reset']}\n", 'neon_orange')
        return formatted_balance, 200, {'Content-Type': 'text/plain'}
    except ccxt.ExchangeError as e:
        error_message = colorize(COLORS['bold'] + COLORS['neon_pink'] + "Error fetching balance:\n" + COLORS['reset'], 'neon_pink')
        error_message += colorize(COLORS['neon_orange'] + str(e) + COLORS['reset'], 'neon_orange')
        return error_message, 500, {'Content-Type': 'text/plain'}

@app.route('/open_orders')
def get_open_orders_terminal():
    try:
        orders = bybit.fetch_open_orders()
        formatted_orders = colorize(COLORS['bold'] + COLORS['neon_lime'] + "** Open Orders **\n" + COLORS['reset'], 'neon_lime')
        if orders:
            for order in orders:
                formatted_orders += colorize(f"{COLORS['neon_orange']}Symbol: {COLORS['neon_cyan']}{order['symbol']}{COLORS['reset']}, ", 'neon_orange')
                formatted_orders += colorize(f"{COLORS['neon_orange']}Side: {COLORS['neon_cyan']}{order['side']}{COLORS['reset']}, ", 'neon_orange')
                formatted_orders += colorize(f"{COLORS['neon_orange']}Type: {COLORS['neon_cyan']}{order['type']}{COLORS['reset']}, ", 'neon_orange')
                formatted_orders += colorize(f"{COLORS['neon_orange']}Price: {COLORS['neon_cyan']}{order['price']}{COLORS['reset']}, ", 'neon_orange')
                formatted_orders += colorize(f"{COLORS['neon_orange']}Amount: {COLORS['neon_cyan']}{order['amount']}{COLORS['reset']}, ", 'neon_orange')
                formatted_orders += colorize(f"{COLORS['neon_orange']}ID: {COLORS['neon_cyan']}{order['id']}{COLORS['reset']}\n", 'neon_orange')
        else:
            formatted_orders += colorize(COLORS['neon_orange'] + "No open orders.\n" + COLORS['reset'], 'neon_orange')
        return formatted_orders, 200, {'Content-Type': 'text/plain'}
    except ccxt.ExchangeError as e:
        error_message = colorize(COLORS['bold'] + COLORS['neon_pink'] + "Error fetching open orders:\n" + COLORS['reset'], 'neon_pink')
        error_message += colorize(COLORS['neon_orange'] + str(e) + COLORS['reset'], 'neon_orange')
        return error_message, 500, {'Content-Type': 'text/plain'}

@app.route('/recent_trades')
def get_recent_trades_terminal():
    try:
        trades = bybit.fetch_my_trades(limit=10)
        formatted_trades = colorize(COLORS['bold'] + COLORS['neon_lime'] + "** Recent Trades **\n" + COLORS['reset'], 'neon_lime')
        if trades:
            for trade in trades:
                formatted_trades += colorize(f"{COLORS['neon_orange']}Symbol: {COLORS['neon_cyan']}{trade['symbol']}{COLORS['reset']}, ", 'neon_orange')
                formatted_trades += colorize(f"{COLORS['neon_orange']}Side: {COLORS['neon_cyan']}{trade['side']}{COLORS['reset']}, ", 'neon_orange')
                formatted_trades += colorize(f"{COLORS['neon_orange']}Price: {COLORS['neon_cyan']}{trade['price']}{COLORS['reset']}, ", 'neon_orange')
                formatted_trades += colorize(f"{COLORS['neon_orange']}Amount: {COLORS['neon_cyan']}{trade['amount']}{COLORS['reset']}, ", 'neon_orange')
                formatted_trades += colorize(f"{COLORS['neon_orange']}Time: {COLORS['neon_cyan']}{trade['datetime']}{COLORS['reset']}\n", 'neon_orange')
        else:
            formatted_trades += colorize(COLORS['neon_orange'] + "No recent trades.\n" + COLORS['reset'], 'neon_orange')
        return formatted_trades, 200, {'Content-Type': 'text/plain'}
    except ccxt.ExchangeError as e:
        error_message = colorize(COLORS['bold'] + COLORS['neon_pink'] + "Error fetching trades:\n" + COLORS['reset'], 'neon_pink')
        error_message += colorize(COLORS['neon_orange'] + str(e) + COLORS['reset'], 'neon_orange')
        return error_message, 500, {'Content-Type': 'text/plain'}

@app.route('/place_order', methods=['POST'])
def place_order_terminal():
    try:
        symbol = request.form.get('symbol')
        side = request.form.get('side')
        order_type = request.form.get('type')
        amount = float(request.form.get('amount'))
        price = request.form.get('price')  # Optional for market orders
        stop_price = request.form.get('stop_price')  # For stop-loss/take-profit

        if not all([symbol, side, order_type, amount]):
            return colorize(COLORS['neon_pink'] + "Missing required parameters: symbol, side, type, amount\n" + COLORS['reset'], 'neon_pink'), 400, {'Content-Type': 'text/plain'}

        params = {}
        if order_type == 'market':
            order = bybit.create_market_order(symbol, side, amount)
        elif order_type == 'limit':
            if not price:
                return colorize(COLORS['neon_pink'] + "Price required for limit orders\n" + COLORS['reset'], 'neon_pink'), 400, {'Content-Type': 'text/plain'}
            order = bybit.create_limit_order(symbol, side, amount, float(price))
        elif order_type == 'stop-loss':
            if not stop_price:
                return colorize(COLORS['neon_pink'] + "Stop price required for stop-loss orders\n" + COLORS['reset'], 'neon_pink'), 400, {'Content-Type': 'text/plain'}
            params['stopPrice'] = float(stop_price)
            order = bybit.create_order(symbol, 'market', side, amount, params=params)
        elif order_type == 'take-profit':
            if not stop_price:
                return colorize(COLORS['neon_pink'] + "Stop price required for take-profit orders\n" + COLORS['reset'], 'neon_pink'), 400, {'Content-Type': 'text/plain'}
            params['stopPrice'] = float(stop_price)
            order = bybit.create_order(symbol, 'market', side, amount, params=params)
        else:
            return colorize(COLORS['neon_pink'] + "Invalid order type. Use: market, limit, stop-loss, take-profit\n" + COLORS['reset'], 'neon_pink'), 400, {'Content-Type': 'text/plain'}

        response = colorize(COLORS['bold'] + COLORS['neon_lime'] + f"** {order_type.capitalize()} Order Placed **\n" + COLORS['reset'], 'neon_lime')
        response += colorize(f"{COLORS['neon_orange']}Symbol: {COLORS['neon_cyan']}{order['symbol']}{COLORS['reset']}, ", 'neon_orange')
        response += colorize(f"{COLORS['neon_orange']}Side: {COLORS['neon_cyan']}{order['side']}{COLORS['reset']}, ", 'neon_orange')
        response += colorize(f"{COLORS['neon_orange']}Type: {COLORS['neon_cyan']}{order['type']}{COLORS['reset']}, ", 'neon_orange')
        response += colorize(f"{COLORS['neon_orange']}Amount: {COLORS['neon_cyan']}{order['amount']}{COLORS['reset']}, ", 'neon_orange')
        if order.get('price'): response += colorize(f"{COLORS['neon_orange']}Price: {COLORS['neon_cyan']}{order['price']}{COLORS['reset']}, ", 'neon_orange')
        if stop_price: response += colorize(f"{COLORS['neon_orange']}Stop Price: {COLORS['neon_cyan']}{stop_price}{COLORS['reset']}, ", 'neon_orange')
        response += colorize(f"{COLORS['neon_orange']}ID: {COLORS['neon_cyan']}{order['id']}{COLORS['reset']}\n", 'neon_orange')
        return response, 200, {'Content-Type': 'text/plain'}
    except ccxt.ExchangeError as e:
        error_message = colorize(COLORS['bold'] + COLORS['neon_pink'] + "Error placing order:\n" + COLORS['reset'], 'neon_pink')
        error_message += colorize(COLORS['neon_orange'] + str(e) + COLORS['reset'], 'neon_orange')
        return error_message, 500, {'Content-Type': 'text/plain'}

@app.route('/cancel_order', methods=['POST'])
def cancel_order_terminal():
    try:
        order_id = request.form.get('order_id')
        if not order_id:
            return colorize(COLORS['neon_pink'] + "Missing required parameter: order_id\n" + COLORS['reset'], 'neon_pink'), 400, {'Content-Type': 'text/plain'}
        bybit.cancel_order(order_id)
        response = colorize(COLORS['bold'] + COLORS['neon_lime'] + "** Order Cancelled **\n" + COLORS['reset'], 'neon_lime')
        response += colorize(f"{COLORS['neon_orange']}Order ID: {COLORS['neon_cyan']}{order_id}{COLORS['reset']}\n", 'neon_orange')
        return response, 200, {'Content-Type': 'text/plain'}
    except ccxt.ExchangeError as e:
        error_message = colorize(COLORS['bold'] + COLORS['neon_pink'] + "Error cancelling order:\n" + COLORS['reset'], 'neon_pink')
        error_message += colorize(COLORS['neon_orange'] + str(e) + COLORS['reset'], 'neon_orange')
        return error_message, 500, {'Content-Type': 'text/plain'}

if __name__ == '__main__':
    app.run(debug=True)
EOF
echo -e "${NEON_LIME} app.py created.${RESET}"

# Step 2: Create bybit_terminal_viewer.sh (Bash script with all order types)
echo -e "\n${NEON_CYAN}[2/6] Creating bybit_terminal_viewer.sh (Bash script with all order types)...${RESET}"
cat > bybit_terminal_viewer.sh << EOF
#!/bin/bash

API_URL="http://127.0.0.1:5000"

# ANSI color codes matching app.py
COLORS=(
    "reset='\033[0m'"
    "neon_lime='\033[92m'"
    "neon_cyan='\033[96m'"
    "neon_purple='\033[95m'"
    "neon_orange='\033[93m'"
    "neon_pink='\033[91m'"
    "bold='\033[1m'"
    "underline='\033[4m'"
)
eval "\${COLORS[@]}" # Make colors available as variables

while true; do
  menu_output=\$(curl -s "\$API_URL/")
  echo "\$menu_output"
  read -p "" choice

  case "\$choice" in
    1)
      balance_output=\$(curl -s "\$API_URL/account_balance")
      echo "\$balance_output"
      ;;
    2)
      orders_output=\$(curl -s "\$API_URL/open_orders")
      echo "\$orders_output"
      ;;
    3)
      trades_output=\$(curl -s "\$API_URL/recent_trades")
      echo "\$trades_output"
      ;;
    4)
      echo -e "\${neon_cyan}Enter symbol (e.g., BTCUSDT): \${reset}"
      read symbol
      echo -e "\${neon_cyan}Enter side (buy/sell): \${reset}"
      read side
      echo -e "\${neon_cyan}Enter order type (market/limit/stop-loss/take-profit): \${reset}"
      read order_type
      echo -e "\${neon_cyan}Enter amount: \${reset}"
      read amount
      if [ "\$order_type" = "limit" ]; then
        echo -e "\${neon_cyan}Enter price: \${reset}"
        read price
      else
        price=""
      fi
      if [ "\$order_type" = "stop-loss" ] || [ "\$order_type" = "take-profit" ]; then
        echo -e "\${neon_cyan}Enter stop price: \${reset}"
        read stop_price
      else
        stop_price=""
      fi
      order_output=\$(curl -s -X POST "\$API_URL/place_order" -d "symbol=\$symbol&side=\$side&type=\$order_type&amount=\$amount&price=\$price&stop_price=\$stop_price")
      echo "\$order_output"
      ;;
    5)
      echo -e "\${neon_cyan}Enter order ID to cancel: \${reset}"
      read order_id
      cancel_output=\$(curl -s -X POST "\$API_URL/cancel_order" -d "order_id=\$order_id")
      echo "\$cancel_output"
      ;;
    6)
      echo -e "\n\${neon_purple}Exiting...\${reset}"
      break
      ;;
    *)
      echo -e "\n\${neon_orange}Invalid option. Please choose 1-6.\${reset}"
      ;;
  esac
  echo ""
done
EOF
echo -e "${NEON_LIME} bybit_terminal_viewer.sh created.${RESET}"

# Step 3: Set API Keys in ~/.bashrc
echo -e "\n${NEON_CYAN}[3/6] Setting API Keys as Environment Variables in ~/.bashrc...${RESET}"
echo "export BYBIT_API_KEY='YOUR_BYBIT_API_KEY_HERE'" >> ~/.bashrc
echo "export BYBIT_SECRET_KEY='YOUR_BYBIT_SECRET_KEY_HERE'" >> ~/.bashrc
echo -e "${NEON_ORANGE} IMPORTANT: You MUST replace 'YOUR_BYBIT_API_KEY_HERE' and${RESET}"
echo -e "${NEON_ORANGE}            'YOUR_BYBIT_SECRET_KEY_HERE' with your actual API keys!${RESET}"
echo -e "${NEON_LIME} Environment variables set in ~/.bashrc.${RESET}"

# Step 4: Apply Environment Variables
echo -e "\n${NEON_CYAN}[4/6] Applying Environment Variables to current session...${RESET}"
source ~/.bashrc
echo -e "${NEON_LIME} Environment variables applied to current session.${RESET}"

# Step 5: Install Python and libraries
echo -e "\n${NEON_CYAN}[5/6] Installing Python and required libraries (flask ccxt)...${RESET}"
pkg install python -y
pip install flask ccxt
echo -e "${NEON_LIME} Python, Flask, and ccxt installed.${RESET}"

# Step 6: Make script executable
echo -e "\n${NEON_CYAN}[6/6] Making bybit_terminal_viewer.sh executable...${RESET}"
chmod +x bybit_terminal_viewer.sh
echo -e "${NEON_LIME} bybit_terminal_viewer.sh is now executable.${RESET}"

# Final Output
echo -e "\n${NEON_PURPLE}${BOLD}--------------------------------------------------${RESET}"
echo -e "${NEON_LIME}${BOLD}Setup Complete!${RESET}"
echo -e "\n${NEON_CYAN}To run the Neon Bybit Terminal Viewer with All Order Types:${RESET}"
echo -e "${NEON_ORANGE}1. In one Termux session, run: ${NEON_CYAN}python app.py${RESET}"
echo -e "${NEON_ORANGE}2. In a *separate* Termux session, run: ${NEON_CYAN}./bybit_terminal_viewer.sh${RESET}"
echo -e "${NEON_PURPLE}${BOLD}--------------------------------------------------${RESET}\n"
