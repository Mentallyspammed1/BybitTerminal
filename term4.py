#!/usr/bin/env python3
import os,time,hashlib,hmac,urllib.parse,json,threading,numpy as np,plotext as plt,smtplib
from email.message import EmailMessage
import requests,pandas as pd,ccxt
from colorama import init,Fore,Style
from dotenv import load_dotenv
from datetime import datetime,timedelta
from indicators import FibonacciPivotPoints

init(autoreset=True);load_dotenv()
CONFIG={'api_key':os.getenv("BYBIT_API_KEY"),'api_secret':os.getenv("BYBIT_API_SECRET"),'email':{'server':os.getenv("EMAIL_SERVER"),'user':os.getenv("EMAIL_USER"),'password':os.getenv("EMAIL_PASSWORD"),'receiver':os.getenv("EMAIL_RECEIVER")},'risk':{'max_per_trade':0.02,'max_leverage':100,'daily_loss_limit':0.1}}
class BTT:
    def __init__(self):self.exch=self._init_exch();self.rm=RM(CONFIG['risk']);self.ntf=NH(CONFIG['email']);self.se=SE();self.ao={};self.mdc={};self.fpp_indicator = FibonacciPivotPoints(config={}) # Initialize FPP Indicator
    def _init_exch(self):
        if not CONFIG['api_key'] or not CONFIG['api_secret']:raise ValueError("API keys missing")
        return ccxt.bybit({'apiKey':CONFIG['api_key'],'secret':CONFIG['api_secret'],'options':{'defaultType':'swap'}})
    def execute_order(self,otype,sym,side,amt,price=None,params=None):
        try:op={'symbol':sym,'type':otype,'side':side,'amount':amt,'params':params or {}}
        if otype=='limit':op['price']=price
        order=self.exch.create_order(**op);self.ao[order['id']]=order;self.ntf.send_alert(f"Order executed: {order['id']}");return order
        except ccxt.NetworkError as e:self.ntf.send_alert(f"Net err: {str(e)}")
        except ccxt.ExchangeError as e:self.ntf.send_alert(f"Exch err: {str(e)}");return None
    def cond_order(self):
        print(Fore.CYAN+"\nCond Order Types:\n1. Stop-Limit\n2. Trailing Stop\n3. OCO");ch=input("Select type: ")
        sym=input("Symbol: ").upper();side=input("Side (buy/sell): ").lower();amt=float(input("Quantity: "))
        if ch=='1':stop_pr=float(input("Stop Price: "));lim_pr=float(input("Limit Price: "));self._sl(sym,side,amt,stop_pr,lim_pr)
        elif ch=='2':trail_val=float(input("Trailing Value ($): "));self._ts(sym,side,amt,trail_val)
        elif ch=='3':price1=float(input("Price 1: "));price2=float(input("Price 2: "));self._oco(sym,side,amt,price1,price2)
    def _sl(self,sym,side,amt,stop,limit):params={'stopPrice':stop,'price':limit,'type':'STOP'}
    try:o=self.exch.create_order(symbol=sym,type='limit',side=side,amount=amt,price=limit,params=params);print(Fore.GREEN+f"Stop-limit placed: {o['id']}")
    except Exception as e:print(Fore.RED+f"Err: {e}")
    def chart_adv(self,sym,tf='1h',periods=100):ohlcv=self.exch.fetch_ohlcv(sym,tf,limit=periods);closes=[x[4] for x in ohlcv];plt.clear_figure();plt.plot(closes);plt.title(f"{sym} Price Chart ({tf})");plt.show()
    ao=input("Overlay RSI? (y/n): ").lower();if ao=='y':self._chart_rsi(closes)
    def _chart_rsi(self,closes):rsi_vals=rsi(pd.Series(closes),14);plt.plot(rsi_vals,color='red');plt.ylim(0,100);plt.show()
    def backtest(self):sym=input("Symbol: ").upper();tf=input("Timeframe (1h/4h/1d): ");strat_name=input("Strategy (ema/macd): ").lower()
    try:data=self.exch.fetch_ohlcv(sym,tf,limit=1000)
    if not data:print(Fore.RED+"No data for backtest.");return
    df=pd.DataFrame(data,columns=['timestamp','open','high','low','close','volume']);df['timestamp']=pd.to_datetime(df['timestamp'],unit='ms');df.set_index('timestamp',inplace=True)
    bt_res=self.se.run_backtest(df,strat_name);print(Fore.CYAN+f"\n--- Backtest Results ({strat_name.upper()}):");print(Fore.WHITE+f"Total Return: {Fore.GREEN}{bt_res['tot_ret_perc']:.2f}%");print(Fore.WHITE+f"Max Drawdown: {Fore.RED}{bt_res['max_dd_perc']:.2f}%")
    plot_c=input(Fore.YELLOW+"Plot cum rets? (y/n): ").lower();if plot_c=='y':plt.clear_figure();plt.plot(bt_res['cum_rets'].fillna(0));plt.title(f"{strat_name.upper()} Strategy Cumulative Returns for {sym}");plt.xlabel("Date");plt.ylabel("Cumulative Returns");plt.show()
    except ccxt.ExchangeError as e:print(Fore.RED+f"Bybit Err: {e}")
    except ValueError as e:print(Fore.RED+str(e))
    except Exception as e:print(Fore.RED+f"Backtest Err: {e}")

    def disp_adv_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔═══════════════════════════════╗\n║      ADVANCED FEATURES        ║\n╠═══════════════════════════════╣\n║ 1. Algorithmic Trading        ║\n║ 2. Risk Management Tools      ║\n║ 3. Market Analysis Suite      ║\n║ 4. Notification Setup         ║\n║ 5. Back to Main Menu          ║\n╚═══════════════════════════════╝\n""")
        ch=input(Fore.YELLOW+"Select feature (1-5): ")
        if ch=='1':self.disp_algo_menu()
        elif ch=='2':self.disp_rm_menu()
        elif ch=='3':self.disp_ma_menu()
        elif ch=='4':self.disp_notif_menu()
        elif ch=='5':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-5.");time.sleep(1.5)

    def disp_rm_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔═══════════════════════════════╗\n║    RISK MANAGEMENT TOOLS      ║\n╠═══════════════════════════════╣\n║ 1. Margin Calculator          ║\n║ 2. Set Max Risk Percentage    ║\n║ 3. Set Leverage Configuration ║\n║ 4. Back to Advanced Features  ║\n╚═══════════════════════════════╝\n""")
        ch=input(Fore.YELLOW+"Select tool (1-4): ")
        if ch=='1':self.margin_calc()
        elif ch=='3':self.set_lev_menu()
        elif ch=='4':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-4.");time.sleep(1.5)

    def disp_algo_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔═══════════════════════════════╗\n║    ALGORITHMIC TRADING        ║\n╠═══════════════════════════════╣\n║ 1. Run Strategy Backtest      ║\n║ 2. Live Strategy Exec (WIP)   ║\n║ 3. Strategy Config (WIP)    ║\n║ 4. Back to Advanced Features  ║\n╚═══════════════════════════════╝\n""")
        ch=input(Fore.YELLOW+"Select action (1-4): ")
        if ch=='1':self.backtest()
        elif ch=='4':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-4.");time.sleep(1.5)

    def disp_ma_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔═══════════════════════════════╗\n║    MARKET ANALYSIS SUITE      ║\n╠═══════════════════════════════╣\n║ 1. Adv Chart     ║\n║ 2. Mkt Sentiment       ║\n║ 3. Funding Rate           ║\n║ 4. ST Analyze         ║\n║ 5. BB Analyze    ║\n║ 6. MACD Analyze        ║\n║ 7. FPP Analyze         ║\n║ 8. Back to Adv Feat  ║\n╚═══════════════════════════════╝\n""")
        ch=input(Fore.YELLOW+"Select analysis (1-8): ")
        if ch=='1':sym=input(Fore.YELLOW+"Enter symbol: ").upper();tf=input(Fore.YELLOW+"Enter timeframe: ").lower();self.chart_adv(sym,tf)
        elif ch=='2':sentiment=get_msentiment();print(Fore.CYAN+"\nMarket Sentiment (Fear/Greed Index):");print(Fore.WHITE+f"{sentiment}");input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")
        elif ch=='3':sym=input(Fore.YELLOW+"Enter symbol: ").upper();self.fetch_frate(sym)
        elif ch=='7': self.analyze_fpp_menu() # Call Fibonacci Pivot Points Menu
        elif ch=='8':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-8.");time.sleep(1.5)

    def disp_notif_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔═══════════════════════════════╗\n║    NOTIFICATION SETUP         ║\n╠═══════════════════════════════╣\n║ 1. Set Price Alert            ║\n║ 2. Cfg Email Alerts     ║\n║ 3. Back to Adv Feat  ║\n╚═══════════════════════════════╝\n""")
        ch=input(Fore.YELLOW+"Select action (1-3): ")
        if ch=='1':sym=input(Fore.YELLOW+"Symbol for alert: ").upper();price=float(input(Fore.YELLOW+"Target price: "));self.ntf.price_alert(sym,price);print(Fore.GREEN+f"Price alert set {sym} at {price}.");input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")
        elif ch=='2':self.cfg_email_menu()
        elif ch=='3':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-3.");time.sleep(1.5)

    def cfg_email_menu(self):print(Fore.CYAN+Style.BRIGHT+"\n--- Configure Email Alerts ---");server=input(Fore.YELLOW+"SMTP Server (e.g., smtp.gmail.com): ");user=input(Fore.YELLOW+"Email User: ");password=input(Fore.YELLOW+"Email Pass: ");
    smtp_det={'server':server,'user':user,'password':password};self.ntf.cfg_email(smtp_det);input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def margin_calc(self):os.system('clear');print(Fore.CYAN+Style.BRIGHT+"╔══════════════════════════════════╗\n║        MARGIN CALCULATOR         ║\n╚══════════════════════════════════╝")
    bal=float(input(Fore.YELLOW+"Account Balance (USDT): "));lev=int(input(Fore.YELLOW+"Leverage (e.g., 10x): "));risk_perc=float(input(Fore.YELLOW+"Risk % per trade: "));entry=float(input(Fore.YELLOW+"Entry Price: "));sl=float(input(Fore.YELLOW+"Stop Loss Price: "))
    self.rm.set_lev(lev);size=self.rm.pos_size(entry,sl,bal);print(Fore.CYAN+"\n--- Pos Calc ---");print(Fore.WHITE+f"Pos Size (Contracts): {Fore.GREEN}{size}");print(Fore.WHITE+f"Risk Amt (USDT): ${Fore.YELLOW}{bal*risk_perc/100:.2f}");print(Fore.WHITE+f"Leverage Used: {Fore.MAGENTA}{lev}x");input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")
    def set_lev_menu(self):lev=int(input(Fore.YELLOW+"Set Leverage (1-100): "));self.rm.set_lev(lev);print(Fore.GREEN+f"Leverage set to {self.rm.leverage}x");input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def fetch_frate(self,sym):
        if not self.exch:print(Fore.RED+Style.BRIGHT+"CCXT not init.");return None
        try:fr_data=self.exch.fetch_funding_rate(sym);
        if fr_data and 'fundingRate' in fr_data:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"╔════════════FUNDING RATE═════════════╗")
        rate=float(fr_data['fundingRate'])*100;print(Fore.WHITE+Style.BRIGHT+f"\nCurrent funding rate for {Fore.GREEN}{sym}{Fore.WHITE}: {Fore.GREEN}{rate:.4f}%")
        if rate>0:rc=Fore.GREEN;dir="Positive"
        elif rate<0:rc=Fore.RED;dir="Negative"
        else:rc=Fore.YELLOW;dir="Neutral"
        print(Fore.WHITE+Style.BRIGHT+f"Funding Rate is: {rc}{dir}{Fore.WHITE}");return fr_data['fundingRate']
        else:print(Fore.RED+Style.BRIGHT+f"Could not fetch funding rate {sym}");return None
        except ccxt.ExchangeError as e:print(Fore.RED+Style.BRIGHT+f"Bybit Err: {e}")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err fetch frate: {e}")
        finally:input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def analyze_fpp_menu(self): # Fibonacci Pivot Points Analysis Menu
        sym = input(Fore.YELLOW + "Enter Futures symbol for FPP analysis (e.g., BTCUSDT): ").upper()
        tf = input(Fore.YELLOW + "Enter timeframe for FPP (e.g., 1d): ").lower()
        try:
            bars = self.exch.fetch_ohlcv(sym, tf, limit=2) # Get last two bars for calculation and current price
            if not bars or len(bars) < 2:
                print(Fore.RED + Style.BRIGHT + f"Could not fetch enough OHLCV data for {sym} in {tf}")
                return
            df = pd.DataFrame(bars, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            current_price = self.exch.fetch_ticker(sym)['last'] # Fetch current price for signals
            fpp_df = self.fpp_indicator.calculate(df)
            signals = self.fpp_indicator.generate_trading_signals(df, current_price)

            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + f"╔══════FIBONACCI PIVOT POINTS ({sym} - {tf})══════╗")
            print(Fore.WHITE + Style.BRIGHT + "\nFibonacci Pivot Levels:")
            for level in self.fpp_indicator.level_names: # Use level_names from indicator instance
                price = fpp_df.iloc[0][level] # Access price from DataFrame
                signal_name = self.fpp_indicator.level_names[level]
                print(f"{Fore.WHITE}{signal_name}: {Fore.GREEN}{price:.4f}") # Display with color-coded names

            if signals:
                print(Fore.WHITE + Style.BRIGHT + "\nTrading Signals:")
                for signal in signals:
                    print(signal)
            else:
                print(Fore.YELLOW + "\nNo strong signals at this time.")

        except ccxt.ExchangeError as e:
            print(Fore.RED + Style.BRIGHT + f"Bybit Exchange Error: {e}")
        except Exception as e:
            print(Fore.RED + Style.BRIGHT + f"Error analyzing Fibonacci Pivot Points: {e}")
        finally:
            input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter to continue...")


    def disp_mkt_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔════════════MARKET DATA═════════════╗\n║         (Using CCXT)             ║\n╚═══════════════════════════════╝\nChoose data:\n1. Symbol Price\n2. Order Book\n3. Symbols List\n4. RSI\n5. ATR\n6. FPP\n7. Adv Chart\n8. Mkt Sentiment\n9. Funding Rate\n10. Back to Main Menu\n""")
        ch=input(Fore.YELLOW+"Select data (1-10): ")
        if ch=='1':sym=input(Fore.YELLOW+"Futures symbol (e.g., BTCUSDT): ").upper();self.fetch_sym_price(sym)
        elif ch=='2':sym=input(Fore.YELLOW+"Futures symbol (e.g., BTCUSDT): ").upper();self.get_ob(sym)
        elif ch=='3':self.list_syms()
        elif ch=='4':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe (e.g., 1h): ").lower();self.disp_rsi(sym,tf)
        elif ch=='5':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe (e.g., 1h): ").lower();p=int(input(Fore.YELLOW+"ATR Period (e.g., 14): ") or 14);self.disp_atr(sym,tf,p)
        elif ch=='6':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe for FPP (e.g., 1d): ").lower();self.disp_fpp(sym,tf)
        elif ch=='7':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe (e.g., 1h): ").lower();self.chart_adv(sym,tf)
        elif ch=='8':sentiment=get_msentiment();print(Fore.CYAN+"\nMarket Sentiment (Fear/Greed Index):");print(Fore.WHITE+f"{sentiment}");input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")
        elif ch=='9':sym=input(Fore.YELLOW+"Enter symbol: ").upper();self.fetch_frate(sym)
        elif ch=='10':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-10.");time.sleep(1.5)

    def disp_trade_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔════════════TRADE ACTIONS════════════╗\n║      (Using Direct Requests)      ║\n╚═══════════════════════════════╝\nChoose action:\n1. Market Order\n2. Limit Order\n3. Cond Order\n8. Back to Main Menu\n""")
        ch=input(Fore.YELLOW+"Select action (1-8): ")
        if ch=='1':self.place_mkt_order()
        elif ch=='2':self.place_lmt_order()
        elif ch=='3':self.cond_order()
        elif ch=='8':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-8.");time.sleep(1.5)

    def disp_acc_menu(self):
        while True:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔════════════ACCOUNT OPS═════════════╗\n║     (Using CCXT & Pandas)        ║\n╚═══════════════════════════════╝\nChoose action:\n1. View Balance\n2. View Order History\n3. Margin Calculator\n6. Back to Main Menu\n""")
        ch=input(Fore.YELLOW+"Select action (1-6): ")
        if ch=='1':self.view_bal()
        elif ch=='2':self.view_ord_hist()
        elif ch=='3':self.margin_calc()
        elif ch=='6':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-6.");time.sleep(1.5)

    def disp_main_menu(self):
        os.system('clear');print(Fore.CYAN+Style.BRIGHT+"""\n╔══════════════════════════════════╗\n║   Bybit Futures Terminal v1.0    ║\n║  Full Feature - Pyrrmethus Edit   ║\n║       Powered by Pyrrmethus       ║\n╚══════════════════════════════════╝\nChoose a category:\n1. Account Operations\n2. Market Data\n3. Trading Actions\n4. Advanced Features\n5. Display API Keys (Debug)\n6. Exit\n""")
        return input(Fore.YELLOW+Style.BRIGHT+"Enter choice (1-6): ")

    def handle_acc_menu(self):
        while True:ch_acc=self.disp_acc_menu()
        if ch_acc=='1':self.view_bal()
        elif ch_acc=='2':self.view_ord_hist()
        elif ch_acc=='3':self.margin_calc()
        elif ch_acc=='6':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-6.")

    def handle_mkt_menu(self):
        while True:ch_mkt=self.disp_mkt_menu()
        if ch_mkt=='1':sym=input(Fore.YELLOW+"Futures symbol (e.g., BTCUSDT): ").upper();self.fetch_sym_price(sym)
        elif ch_mkt=='2':sym=input(Fore.YELLOW+"Futures symbol (e.g., BTCUSDT): ").upper();self.get_ob(sym)
        elif ch_mkt=='3':self.list_syms()
        elif ch_mkt=='4':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe (e.g., 1h): ").lower();self.disp_rsi(sym,tf)
        elif ch_mkt=='5':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe (e.g., 1h): ").lower();p=int(input(Fore.YELLOW+"ATR Period (e.g., 14): ") or 14);self.disp_atr(sym,tf,p)
        elif ch_mkt=='6':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe for FPP (e.g., 1d): ").lower();self.disp_fpp(sym,tf)
        elif ch_mkt=='7':sym=input(Fore.YELLOW+"Futures symbol: ").upper();tf=input(Fore.YELLOW+"Timeframe (e.g., 1h): ").lower();self.chart_adv(sym,tf)
        elif ch_mkt=='8':sentiment=get_msentiment();print(Fore.CYAN+"\nMkt Sentiment (Fear/Greed Index):");print(Fore.WHITE+f"{sentiment}");input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")
        elif ch_mkt=='9':sym=input(Fore.YELLOW+"Enter symbol: ").upper();self.fetch_frate(sym)
        elif ch_mkt=='10':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice 1-10.")

    def handle_trade_menu(self):
        if CONFIG['api_key'] and CONFIG['api_secret']:while True:ch_trade=self.disp_trade_menu()
        if ch_trade=='1':self.place_mkt_order()
        elif ch_trade=='2':self.place_lmt_order()
        elif ch_trade=='3':self.cond_order()
        elif ch_trade=='8':break
        else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-8.")
        else:print(Fore.RED+Style.BRIGHT+"Trading actions disabled: API keys missing.");input(Fore.YELLOW+Style.BRIGHT+"Press Enter...")

    def main(self):
        while True:
            choice_main=self.disp_main_menu()
            if choice_main=='1':self.handle_acc_menu()
            elif choice_main=='2':self.handle_mkt_menu()
            elif choice_main=='3':self.handle_trade_menu()
            elif choice_main=='4':self.disp_adv_menu()
            elif choice_main=='5':self.debug_apikeys()
            elif choice_main=='6':print(Fore.MAGENTA+Style.BRIGHT+"Exiting terminal.");break
            else:print(Fore.RED+Style.BRIGHT+"Invalid choice. 1-6.");time.sleep(1.5)
        print(Fore.CYAN+Style.BRIGHT+"Terminal closed.")

    def view_bal(self):
        if not self.exch:print(Fore.Red+Style.BRIGHT+"CCXT not init.");return
        try:bal=self.exch.fetch_balance()
        if bal and "USDT" in bal and isinstance(bal["USDT"],dict):os.system('clear');print(Fore.CYAN+Style.BRIGHT+"╔═══════════ACCOUNT BALANCE════════════╗")
        ubal=bal.get("USDT",{})
        tbal=ubal.get("total",float('nan'));fbal=ubal.get("free",float('nan'));df=pd.DataFrame([{"currency":"USDT","total":tbal,"free":fbal}])
        if not df.empty and not df[["total","free"]].isnull().all().all():print(Fore.WHITE+Style.BRIGHT+"\nBalances (USDT Perpetual Futures):");print(Fore.GREEN+df[["currency","total","free"]].to_string(index=False,formatters={"total":"{:.4f}".format,"free":"{:.4f}".format}))
        else:print(Fore.YELLOW+"USDT balance unavailable.")
        print(Fore.CYAN+Style.BRIGHT+"\n---------------------------------------")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err fetch bal: {e}")
        input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def view_ord_hist(self):
        if not self.exch:print(Fore.RED+"CCXT not init.");return
        try:sym=input(Fore.YELLOW+"Futures symbol (e.g., BTC/USDT): ").upper()
        if "/" not in sym:sym+="/USDT"
        ords=self.exch.fetch_closed_orders(symbol=sym)+self.exch.fetch_canceled_orders(symbol=sym)
        if ords:os.system('clear');print(Fore.CYAN+Style.BRIGHT+f"╔══════════ORDER HISTORY FOR {sym:<8}══════════╗")
        ord_df=pd.DataFrame(ords);
        if not ord_df.empty:ord_df["datetime"]=pd.to_datetime(ord_df["datetime"]);ord_df=ord_df[["datetime","id","side","amount","price","status","type","symbol"]];print(Fore.WHITE+Style.BRIGHT+"\nOrder History:");print(Fore.CYAN+"-"*120)
        print(Fore.WHITE+ord_df.to_string(index=False,formatters={"price":"{:.2f}".format,"amount":"{:.4f}".format}))
        print(Fore.CYAN+"-"*120)
        else:print(Fore.YELLOW+f"No orders found for {sym}")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err fetch ord hist: {e}")
        input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def fetch_sym_price(self,sym):
        if not self.exch:print(Fore.RED+Style.BRIGHT+"CCXT not init.");return
        try:tkr=self.exch.fetch_ticker(sym)
        if tkr and "last" in tkr:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"╔════════════SYMBOL PRICE═════════════╗")
        print(Fore.WHITE+Style.BRIGHT+f"\nCurrent price of {Fore.GREEN}{sym}{Fore.WHITE}: {Fore.GREEN}{tkr['last']:.2f}")
        else:print(Fore.RED+Style.BRIGHT+f"Could not fetch price {sym}")
        except ccxt.ExchangeError as e:print(Fore.RED+Style.BRIGHT+f"Bybit Err: {e}")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err fetch price: {e}")
        input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def get_ob(self,sym):
        if not self.exch:print(Fore.RED+Style.BRIGHT+"CCXT not init.");return
        try:ob=self.exch.fetch_order_book(sym)
        if ob:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"╔════════════ORDER BOOK═════════════╗")
        bid_df=pd.DataFrame(ob["bids"],columns=["Price","Amount"]).head(10);ask_df=pd.DataFrame(ob["asks"],columns=["Price","Amount"]).head(10)
        print(Fore.GREEN+Style.BRIGHT+f"\nTop 10 Bids ({sym}):");print(Fore.GREEN+bid_df.to_string(index=False,formatters={'Price':'{:.4f}'.format}))
        print(Fore.MAGENTA+Style.BRIGHT+f"\nTop 10 Asks ({sym}):");print(Fore.MAGENTA+ask_df.to_string(index=False,formatters={'Price':'{:.4f}'.format}))
        else:print(Fore.RED+Style.BRIGHT+f"Could not fetch order book {sym}")
        except ccxt.ExchangeError as e:print(Fore.RED+Style.BRIGHT+f"Bybit Err: {e}")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err fetch ob: {e}")
        input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def list_syms(self):
        if not self.exch:print(Fore.RED+Style.BRIGHT+"CCXT not init.");return
        try:syms=self.exch.symbols
        if syms:os.system('clear');print(Fore.CYAN+Style.BRIGHT+"╔════════════AVAIL SYMBOLS═════════════╗")
        print(Fore.WHITE+Style.BRIGHT+"\nAvail Futures symbols on Bybit:");print(Fore.GREEN+"\n".join(syms))
        else:print(Fore.RED+Style.BRIGHT+"Could not fetch symbols.")
        except ccxt.ExchangeError as e:print(Fore.RED+Style.BRIGHT+f"Bybit Err: {e}")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err fetch syms: {e}")
        input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def disp_rsi(self,sym,tf):
        if not self.exch:print(Fore.RED+Style.BRIGHT+"CCXT not init.");return
        try:bars=self.exch.fetch_ohlcv(sym,tf,limit=15)
        if not bars:print(Fore.RED+Style.BRIGHT+f"Could not fetch OHLCV data {sym}");return
        df=pd.DataFrame(bars,columns=["timestamp","open","high","low","close","volume"]);df["RSI"]=rsi(df["close"],length=14)
        if not df.empty and "RSI" in df.columns:os.system('clear');print(Fore.CYAN+Style.BRIGHT+f"╔════════════RSI for {sym} ({tf})═══════════╗")
        print(Fore.WHITE+Style.BRIGHT+"\nLast RSI value:");lrsi=df["RSI"].iloc[-1];rsi_color=Fore.GREEN if lrsi<30 else Fore.RED if lrsi>70 else Fore.YELLOW
        print(f"{Fore.WHITE}RSI: {rsi_color}{lrsi:.2f}{Fore.WHITE}");print(Fore.WHITE+Style.BRIGHT+"\nRSI Values:");print(Fore.CYAN+"-"*40)
        print(Fore.GREEN+df[["timestamp","RSI"]].tail(5).to_string(index=False,formatters={'timestamp':lambda x:pd.to_datetime(x,unit='ms')}));print(Fore.CYAN+"-"*40)
        else:print(Fore.RED+Style.BRIGHT+"RSI calc failed.")
        except ccxt.ExchangeError as e:print(Fore.RED+Style.BRIGHT+f"Bybit Err: {e}")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err calc RSI: {e}")
        input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def disp_atr(self,sym,tf,period):
        if not self.exch:print(Fore.RED+Style.BRIGHT+"CCXT not init.");return
        try:bars=self.exch.fetch_ohlcv(sym,tf,limit=period+10)
        if not bars:print(Fore.RED+Style.BRIGHT+f"Could not fetch OHLCV data {sym}");return
        df=pd.DataFrame(bars,columns=["timestamp","open","high","low","close","volume"]);atr_vals=ATR(df,period=period)
        if not atr_vals.empty:last_atr=atr_vals.iloc[-1];os.system('clear');print(Fore.CYAN+Style.BRIGHT+f"╔════════════ATR for {sym} ({tf})═══════════╗")
        print(Fore.WHITE+Style.BRIGHT+f"\nLast {period}-period ATR value:");print(f"{Fore.WHITE}ATR: {Fore.GREEN}{last_atr:.4f}{Fore.WHITE}");print(Fore.WHITE+Style.BRIGHT+"\nATR Values:")
        print(Fore.CYAN+"-"*40);print(Fore.GREEN+atr_vals.tail(5).to_string());print(Fore.CYAN+"-"*40)
        else:print(Fore.RED+Style.BRIGHT+"ATR calc failed.")
        except ccxt.ExchangeError as e:print(Fore.RED+Style.BRIGHT+f"Bybit Err: {e}")
        except Exception as e:print(Fore.RED+Style.BRIGHT+f"Err calc ATR: {e}")
        input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def disp_fpp(self,sym,tf): # Display Fibonacci Pivot Points - Streamlined
        try:
            bars = self.exch.fetch_ohlcv(sym, tf, limit=2)
            if not bars or len(bars) < 2: print(Fore.RED + Style.BRIGHT + f"Err fetch OHLCV data {sym} {tf}"); return
            df = pd.DataFrame(bars, columns=['timestamp', 'Open', 'High', 'Low', 'Close', 'Volume'])
            current_price = self.exch.fetch_ticker(sym)['last']
            fpp_df = self.fpp_indicator.calculate(df)
            signals = self.fpp_indicator.generate_trading_signals(df, current_price)

            os.system('clear')
            print(Fore.CYAN + Style.BRIGHT + f"╔══════FPP ({sym} - {tf})══════╗")
            print(Fore.WHITE + Style.BRIGHT + "\nFibonacci Pivot Levels:")
            for level in self.fpp_indicator.level_names:
                price = fpp_df.iloc[0][level]
                signal_name = self.fpp_indicator.level_names[level]
                print(f"{Fore.WHITE}{signal_name}: {Fore.GREEN}{price:.4f}")
            if signals:
                print(Fore.WHITE + Style.BRIGHT + "\nTrading Signals:")
                for signal in signals: print(signal)
            else: print(Fore.YELLOW + "\nNo strong signals.")

        except ccxt.ExchangeError as e: print(Fore.RED + Style.BRIGHT + f"Bybit Err: {e}")
        except Exception as e: print(Fore.RED + Style.BRIGHT + f"Err analyze FPP: {e}")
        finally: input(Fore.YELLOW + Style.BRIGHT + "\nPress Enter...")


    def debug_apikeys(self):os.system('clear');print(Fore.CYAN+Style.BRIGHT+"╔══════════════DEBUG API KEYS══════════╗")
    print(Fore.CYAN+Style.BRIGHT+"║ "+Fore.RED+"!!! DO NOT SHARE !!!"+Fore.CYAN+" ║");print(Fore.CYAN+Style.BRIGHT+"╚══════════════════════════════════╝")
    print(Fore.YELLOW+Style.BRIGHT+"\nAPI Key (BYBIT_API_KEY):");print(Fore.GREEN+f"  {CONFIG['api_key'] if CONFIG['api_key'] else 'Not Loaded'}");print(Fore.YELLOW+Style.BRIGHT+"\nAPI Secret (BYBIT_API_SECRET):")
    print(Fore.GREEN+f"  {'*'*len(CONFIG['api_secret']) if CONFIG['api_secret'] else 'Not Loaded'}");input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")
    def place_mkt_order(self):sym=input(Fore.YELLOW+"Enter symbol (e.g., BTCUSDT): ").upper();side=input(Fore.YELLOW+"Buy/Sell: ").lower();amt=float(input(Fore.YELLOW+"Enter quantity: "));order_details=order_req(sym,side,"market",amt)
    if order_details:os.system("clear");print(Fore.CYAN+Style.BRIGHT+"╔═══════════MARKET ORDER EXECUTED════════════╗");print(Fore.WHITE+f"\nSymbol: {Fore.GREEN}{sym}");print(Fore.WHITE+f"Side: {Fore.GREEN if side=='buy' else Fore.RED}{side.upper()}");print(Fore.WHITE+f"Amount: {Fore.GREEN}{amt}");
    if order_details.get("orderId"):print(Fore.WHITE+f"Order ID: {Fore.CYAN}{order_details['orderId']}")
    else:print(Fore.RED+Style.BRIGHT+"Market order failed.")
    input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

    def place_lmt_order(self):sym=input(Fore.YELLOW+"Symbol (e.g., BTCUSDT): ").upper();side=input(Fore.YELLOW+"Buy/Sell: ").lower();amt=float(input(Fore.YELLOW+"Quantity: "));price=float(input(Fore.YELLOW+"Enter price: "))
    order_details=order_req(sym,side,"limit",amt,price);
    if order_details:os.system("clear");print(Fore.CYAN+Style.BRIGHT+"╔═══════════LIMIT ORDER PLACED═══════════╗");print(Fore.WHITE+f"\nSymbol: {Fore.GREEN}{sym}");print(Fore.WHITE+f"Side: {Fore.GREEN if side=='buy' else Fore.RED}{side.upper()}");print(Fore.WHITE+f"Amount: {Fore.GREEN}{amt}");print(Fore.WHITE+f"Price: {Fore.GREEN}{price}");
    if order_details.get("orderId"):print(Fore.WHITE+f"Order ID: {Fore.CYAN}{order_details['orderId']}")
    else:print(Fore.RED+Style.BRIGHT+"Limit order failed.")
    input(Fore.YELLOW+Style.BRIGHT+"\nPress Enter...")

def get_msentiment():
    try:resp=requests.get('https://api.alternative.me/fng/');data=resp.json();return data['data'][0]['value']
    except Exception as e:return f"Error: {str(e)}"

if __name__=="__main__":
    terminal = BTT()
    terminal.main()
