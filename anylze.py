import os,logging,requests,pandas as pd,numpy as np,hmac,hashlib,time,json
from datetime import datetime
from dotenv import load_dotenv
from typing import Dict,Tuple,List,Union
from colorama import init,Fore,Style
from zoneinfo import ZoneInfo
from decimal import Decimal,getcontext
getcontext().prec=10;init(autoreset=True);load_dotenv()
AK=os.getenv("BYBIT_API_KEY");AS=os.getenv("BYBIT_API_SECRET")
if not AK or not AS:raise ValueError("BYBIT_API_KEY/SECRET missing")
BU=os.getenv("BYBIT_BASE_URL","https://api.bybit.com");CF="config.json";LD="bot_logs";TZ=ZoneInfo("America/Chicago")
MAR,RDS,REC=3,5,[429,500,502,503,504];NG,NB,NP,NY,NR,RST=Fore.LIGHTGREEN_EX,Fore.CYAN,Fore.MAGENTA,Fore.YELLOW,Fore.LIGHTRED_EX,Style.RESET_ALL;NEY="\033[93m";RES="\033[0m"
os.makedirs(LD,exist_ok=True)
def lc(f:str)->dict:
    try:
        with open(f,"r")as fl:c=json.load(fl)
    except(FileNotFoundError,json.JSONDecodeError):
        print(f"{NY}Config load fail, defaults.{RST}");c={"interval":"15","analysis_interval":30,"retry_delay":5,"momentum_period":10,"momentum_ma_short":12,"momentum_ma_long":26,"volume_ma_period":20,"atr_period":14,"trend_strength_threshold":0.4,"sideways_atr_multiplier":1.5,"indicators":{"ema_alignment":True,"momentum":True,"volume_confirmation":True,"divergence":True,"stoch_rsi":True,"rsi":True,"macd":True},"weight_sets":{"low_volatility":{"ema_alignment":0.4,"momentum":0.3,"volume_confirmation":0.2,"divergence":0.1,"stoch_rsi":0.7,"rsi":0.5,"macd":0.6}}}
    return c
CONFIG=lc(CF)
def fp(p:Decimal)->str:return str(p.quantize(Decimal("0.0001")))
def fcp(s:str,l=None)->Union[Decimal,None]:
    try:
        r=br("GET","/v5/market/tickers",{"symbol":s,"category":"linear"},l);return Decimal(r["result"]["list"][0]["lastPrice"]) if r and r.get("retCode")==0 and r.get("result") and r["result"]["list"]else(l.error(f"{NR}Price fetch fail: {r}{RST}")if l else None,None)[1]
    except Exception as e:l.exception(f"{NR}Price fetch error: {e}{RST}")if l else None;return None
def gs(p:dict)->str:return hmac.new(AS.encode(),"&".join(f"{k}={v}"for k,v in sorted(p.items())).encode(),hashlib.sha256).hexdigest()
def sl(s:str)->logging.Logger:
    ts=datetime.now().strftime("%Y%m%d_%H%M%S");logfn=os.path.join(LD,f"{s}_{ts}.log");l=logging.getLogger(s);l.setLevel(logging.INFO)
    fh=logging.FileHandler(logfn);fh.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"));l.addHandler(fh)
    sh=logging.StreamHandler();sh.setFormatter(logging.Formatter(NB+"%(asctime)s"+RST+" - %(levelname)s - %(message)s"));l.addHandler(sh);return l
def sjr(r:requests.Response,l=None)->Union[dict,None]:
    try:return r.json()
    except ValueError:l.error(NR+f"JSON error: {r.text}{RST}")if l else None;return None
def br(m:str,e:str,p:dict=None,l=None)->Union[dict,None]:
    for retry in range(MAR):
        try:
            p=p or {};ts=str(int(datetime.now(TZ).timestamp()*1000));ps="&".join(f"{k}={v}"for k,v in sorted(p.items()))
            h={"X-BAPI-API-KEY":AK,"X-BAPI-TIMESTAMP":ts,"X-BAPI-SIGN":gs(p)};url=f"{BU}{e}";r=requests.request(m,url,headers=h,params=p if m=="GET"else None,json=p if m=="POST"else None)
            if r.status_code==200:return sjr(r,l)
            elif r.status_code in REC:l.warning(f"{NY}Rate limit. Retry {retry+1}/{MAR} in {RDS}s...{RST}")if l else None;time.sleep(RDS*(2**retry));continue
            else:l.error(f"{NR}Bybit API err: {r.status_code} - {r.text}{RST}")if l else None;return None
        except requests.exceptions.RequestException as exp:l.error(f"{NR}API req fail: {exp}{RST}")if l else None;time.sleep(RDS*(2**retry))
    l.error(f"{NR}Max retries for {e}{RST}")if l else None;return None
def fk(s:str,i:str,limit:int=200,l=None)->pd.DataFrame:
    try:
        r=br("GET","/v5/market/kline",{"symbol":s,"interval":i,"limit":limit,"category":"linear"},l)
        if r and r.get("retCode")==0 and r["result"]and r["result"].get("list"):
            d=r["result"]["list"];cols=["start_time","open","high","low","close","volume"]
            if d and len(d[0])>6 and d[0][6]:cols.append("turnover")
            df=pd.DataFrame(d,columns=cols);df["start_time"]=pd.to_datetime(df["start_time"],unit="ms",errors="coerce")
            for col in ["open","high","low","close","volume","turnover"]:df[col]=pd.to_numeric(df[col],errors="coerce").fillna(0)
            for col in ["open","high","low","close","volume","turnover"]:if col not in df.columns:df[col]=0
            if not {"close","high","low","volume"}.issubset(df.columns):l.error(f"{NR}Kline missing cols.{RST}")if l else None;return pd.DataFrame()
            return df.astype({col:float for col in cols if col!="start_time"})
        l.error(f"{NR}Kline fetch fail: {r}{RST}")if l else None;return pd.DataFrame()
    except Exception as e:l.exception(f"{NR}Kline error: {e}{RST}")if l else None;return pd.DataFrame()
class TA:
    def __init__(self,df:pd.DataFrame,logger:logging.Logger,config:dict,sym:str,inter:str):self.df,self.log,self.lvls,self.fibs,self.cfg,self.sig,self.w_sets,self.u_weights,self.sym,self.inter=df,logger,{},{},config,None,config["weight_sets"],config["weight_sets"]["low_volatility"],sym,inter
    def sma(self,w:int)->pd.Series:try:return self.df["close"].rolling(window=w).mean()
    except KeyError:self.log.error(NR+"Missing 'close' for SMA."+RST)if self.log else None;return pd.Series(dtype="float64")
    def mom(self,p:int=10)->pd.Series:try:return((self.df["close"]-self.df["close"].shift(p))/self.df["close"].shift(p))*100
    except Exception as e:self.log.error(NR+f"Mom err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def fib_ret(self,h:float,l:float,cp:float)->Dict[str,float]:
        diff = h - l
        if diff == 0:return {}
        fib_levels={"Fib 23.6%":h-diff*0.236,"Fib 38.2%":h-diff*0.382,"Fib 50.0%":h-diff*0.5,"Fib 61.8%":h-diff*0.618,"Fib 78.6%":h-diff*0.786,"Fib 88.6%":h-diff*0.886,"Fib 94.1%":h-diff*0.941}
        self.lvls={"Sup":{},"Res":{}};[self.lvls["Sup"].__setitem__(label,value) if value<cp else self.lvls["Res"].__setitem__(label,value) for label,value in fib_levels.items()];self.fibs=fib_levels;return self.fibs
    def pivot_points(self,h:float,l:float,c:float):try:p,r1,s1,r2,s2,r3,s3=(h+l+c)/3,(2*p)-l,(2*p)-h,p+(h-l),p-(h-l),h+2*(p-l),l-2*(h-p);self.lvls.update({"pivot":p,"r1":r1,"s1":s1,"r2":r2,"s2":s2,"r3":r3,"s3":s3})
    except Exception as e:self.log.error(NR+f"Pivot err: {e}"+RST)if self.log else None;self.lvls={}
    def near_lvls(self,cp:float,nl:int=5)->Tuple[List[Tuple[str,float]],List[Tuple[str,float]]]:
        slvls,rlvls=[],[];plvl=lambda label,value:(slvls.append((label,value)) if value<cp else rlvls.append((label,value)))
        [ [plvl(f"{label} ({slabel})",svalue) for slabel,svalue in value.items()if isinstance(svalue,(float,Decimal))]if isinstance(value,dict) else plvl(label,value) for label,value in self.lvls.items()];return sorted(slvls,key=lambda x:abs(x[1]-cp),reverse=True)[-nl:],sorted(rlvls,key=lambda x:abs(x[1]-cp))[:nl]
    def atr(self,w:int=20)->pd.Series:try:tr=pd.concat([self.df["high"]-self.df["low"],abs(self.df["high"]-self.df["close"].shift()),abs(self.df["low"]-self.df["close"].shift())],axis=1).max(axis=1);return tr.rolling(window=w).mean()
    except KeyError as e:self.log.error(NR+f"ATR err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def rsi(self,w:int=14)->pd.Series:
        try:delta=self.df["close"].diff();gain=(delta.where(delta>0,0)).rolling(window=w).mean();loss=(-delta.where(delta<0,0)).rolling(window=w).mean();rs=gain/loss;return 100-(100/(1+rs))
        except Exception as e:self.log.error(NR+f"RSI err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def stoch_rsi(self,rsiw:int=14,stochw:int=12,kw:int=4,dw:int=3)->pd.DataFrame:
        try:rsi=self.rsi(window=rsiw);srsi=(rsi-rsi.rolling(stochw).min())/(rsi.rolling(stochw).max()-rsi.rolling(stochw).min());k=srsi.rolling(window=kw).mean();d=k.rolling(window=dw).mean();return pd.DataFrame({"stoch_rsi":srsi,"k":k,"d":d})
        except Exception as e:self.log.error(NR+f"Stoch RSI err: {e}"+RST)if self.log else None;return pd.DataFrame()
    def mom_ma(self)->None:
        try:p,sma,lma,vma=self.cfg["momentum_period"],self.cfg["momentum_ma_short"],self.cfg["momentum_ma_long"],self.cfg["volume_ma_period"];self.df["momentum"],self.df["momentum_ma_short"],self.df["momentum_ma_long"],self.df["volume_ma"]=self.df["close"].diff(p),self.df["momentum"].rolling(window=sma).mean(),self.df["momentum"].rolling(window=lma).mean(),self.df["volume"].rolling(window=vma).mean()
        except KeyError as e:self.log.error(NR+f"Mom/MA err: {e}"+RST)if self.log else None
    def macd(self)->pd.DataFrame:
        try:c=self.df["close"];ms,ml=c.ewm(span=12,adjust=False).mean(),c.ewm(span=26,adjust=False).mean();macd,sig,hist=ms-ml,macd.ewm(span=9,adjust=False).mean(),macd-sig;return pd.DataFrame({"macd":macd,"signal":sig,"histogram":hist})
        except KeyError:self.log.error(NR+"Missing 'close' for MACD."+RST)if self.log else None;return pd.DataFrame()
    def det_macd_div(self)->str|None:
        if self.df.empty or len(self.df)<30:return None
        mdf=self.macd();return None if mdf.empty else ("bullish" if self.df["close"].iloc[-2]>self.df["close"].iloc[-1] and mdf["histogram"].iloc[-2]<mdf["histogram"].iloc[-1] else "bearish" if self.df["close"].iloc[-2]<self.df["close"].iloc[-1] and mdf["histogram"].iloc[-2]>mdf["histogram"].iloc[-1] else None)
    def ema(self,w:int)->pd.Series:try:return self.df["close"].ewm(span=w,adjust=False).mean()
    except KeyError:self.log.error(NR+"Missing 'close' for EMA."+RST)if self.log else None;return pd.Series(dtype="float64")
    def trend_mom(self)->dict:
        if self.df.empty or len(self.df)<26:return{"trend":"None","strength":0}
        atr=self.atr();trend="Sideways"
        if atr.iloc[-1]==0:self.log.warning(f"{NY}ATR zero, trend strength N/A.{RST}")if self.log else None;return{"trend":"Neutral","strength":0}
        self.mom_ma();trend="Up" if self.df["momentum_ma_short"].iloc[-1]>self.df["momentum_ma_long"].iloc[-1] else "Down" if self.df["momentum_ma_short"].iloc[-1]<self.df["momentum_ma_long"].iloc[-1] else "Sideways";ts=abs(self.df["momentum_ma_short"].iloc[-1]-self.df["momentum_ma_long"].iloc[-1])/atr.iloc[-1];return{"trend":trend,"strength":ts}
    def adx(self,w:int=14)->float:
        try:
            df=self.df.copy();df["TR"]=pd.concat([df["high"]-df["low"],abs(df["high"]-df["close"].shift()),abs(df["low"]-df["close"].shift())],axis=1).max(axis=1)
            df["+DM"]=np.where((df["high"]-df["high"].shift())>(df["low"].shift()-df["low"]),np.maximum(df["high"]-df["high"].shift(),0),0);df["-DM"]=np.where((df["low"].shift()-df["low"])>(df["high"]-df["high"].shift()),np.maximum(df["low"].shift()-df["low"],0),0)
            df["TR"]=df["TR"].rolling(w).sum();df["+DM"]=df["+DM"].rolling(w).sum();df["-DM"]=df["-DM"].rolling(w).sum();df["+DI"]=100*(df["+DM"]/df["TR"]);df["-DI"]=100*(df["-DM"]/df["TR"]);df["DX"]=100*(abs(df["+DI"]-df["-DI"])/(df["+DI"]+df["-DI"]))
            return df["DX"].rolling(w).mean().iloc[-1]
        except Exception as e:self.log.error(NR+f"ADX err: {e}"+RST)if self.log else None;return 0.0
    def obv(self)->pd.Series:try:obv=np.where(self.df['close']>self.df['close'].shift(1),self.df['volume'],np.where(self.df['close']<self.df['close'].shift(1),-self.df['volume'],0));return pd.Series(np.cumsum(obv),index=self.df.index)
    except KeyError as e:self.log.error(NR+f"OBV err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def adi(self)->pd.Series:try:mfm=((self.df['close']-self.df['low'])-(self.df['high']-self.df['close']))/(self.df['high']-self.df['low']);mfv=mfm*self.df['volume'];return mfv.cumsum()
    except Exception as e:self.log.error(NR+f"ADI err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def cci(self,w:int=20)->pd.Series:
        try:tp=(self.df["high"]+self.df["low"]+self.df["close"])/3;sma=tp.rolling(window=w).mean();mad=tp.rolling(window=w).apply(lambda x:np.abs(x-x.mean()).mean(),raw=True);return (tp-sma)/(0.015*mad)
        except Exception as e:self.log.error(NR+f"CCI err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def mfi(self,w:int=14)->pd.Series:
        try:tp=(self.df["high"]+self.df["low"]+self.df["close"])/3;rmf=tp*self.df["volume"];mfr=pd.Series(np.where(tp>tp.shift(),rmf,0)).rolling(w).sum()/(pd.Series(np.where(tp<tp.shift(),rmf,0)).rolling(w).sum()+1e-9);return 100-(100/(1+mfr))
        except Exception as e:self.log.error(NR+f"MFI err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def wr(self,w:int=14)->pd.Series:try:hh=self.df["high"].rolling(window=w).max();ll=self.df["low"].rolling(window=w).min();return -100*(hh-self.df["close"])/(hh-ll)
    except Exception as e:self.log.error(NR+f"WR% err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def psar(self,a=0.02,ma=0.2)->pd.Series:
        psar=pd.Series(index=self.df.index,dtype='float64');psar.iloc[0]=self.df["low"].iloc[0];trend,ep,af=1,self.df['high'].iloc[0],a
        for i in range(1,len(self.df)):
            if trend==1:psar.iloc[i]=psar.iloc[i-1]+af*(ep-psar.iloc[i-1]);if self.df["low"].iloc[i]<psar.iloc[i]:trend,psar.iloc[i],ep,af=-1,ep,self.df["low"].iloc[i],a;elif self.df["high"].iloc[i]>ep:ep,af=self.df["high"].iloc[i],min(af+a,ma)
            elif trend==-1:psar.iloc[i]=psar.iloc[i-1]+af*(ep-psar.iloc[i-1]);if self.df["high"].iloc[i]>psar.iloc[i]:trend,psar.iloc[i],ep,af=1,ep,self.df["high"].iloc[i],a;elif self.df["low"].iloc[i]<ep:ep,af=self.df["low"].iloc[i],min(af+a,ma)
        return psar
    def fve(self)->pd.Series:try:force=self.df["close"].diff()*self.df["volume"];return force.cumsum()
    except KeyError as e:self.log.error(NR+f"FVE err: {e}"+RST)if self.log else None;return pd.Series(dtype="float64")
    def next_lvl_pred(self,cp:float,ns:List[Tuple[str,float]],nr:List[Tuple[str,float]])->str:
        if not ns or not nr:return"No clear prediction"
        cs,cr=min(ns,key=lambda x:abs(x[1]-cp)),min(nr,key=lambda x:abs(x[1]-cp));return f"Support at {cs[0]}: {cs[1]:.2f}"if abs(cs[1]-cp)<abs(cr[1]-cp)else f"Resistance at {cr[0]}: {cr[1]:.2f}"
    def analyze(self,cp:Decimal,ts_out:str):
        h,l,close=self.df["high"].max(),self.df["low"].min(),self.df["close"].iloc[-1];self.fib_ret(h,l,float(cp));self.pivot_points(h,l,close)
        ns,nr=self.near_lvls(float(cp));td,atr=self.trend_mom(),self.atr();t,ts=td.get("trend","?"),td.get("strength",0)
        nl=self.next_lvl_pred(float(cp),ns,nr);obv,rsi,mfi,cci,wr,adx_val,adi,sma20,psar_vals,macd_df=self.obv(),self.rsi(),self.mfi(),self.cci(),self.wr(),self.adx(),self.adi(),self.sma(20),self.psar(),self.macd()
        output=f"""Exchange {self.sym} {self.inter} Bybit\nPrice:   {self.df['close'].iloc[-3]:.2f}|   {self.df['close'].iloc[-2]:.2f}|   {self.df['close'].iloc[-1]:.2f}\nVol:   {self.df['volume'].iloc[-3]:,}|{self.df['volume'].iloc[-2]:,}|{self.df['volume'].iloc[-1]:,}\nATR: {atr.iloc[-1]:.4f}\n\n"""
        def indicator_output(name,indicator,ob=None,os=None):
            vals=indicator.tail(3).tolist();istr=" | ".join([f"{v:.2f}"if isinstance(v,float)else str(v)for v in vals])
            if name=="OBV":p,trend=(NG+"✅"if vals[-1]>vals[-2]and vals[-2]>vals[-3]else NR+"❌"if vals[-1]<vals[-2]and vals[-2]<vals[-3]else NY+"🔄"),("(Inc)"if vals[-1]>vals[-2]and vals[-2]>vals[-3]else"(Dec)"if vals[-1]<vals[-2]and vals[-2]<vals[-3]else"(Neu)");return f"{p}OBV: {istr} {RST}{trend}"
            elif ob and indicator.iloc[-1]>ob:p,s=(NR+"🔥","(OB)");sign=NR+"❌"
            elif os and indicator.iloc[-1]<os:p,s=(NG+"🥶","(OS)");sign=NG+"✅"
            elif vals[-1]>vals[-2]:p,s=(NG+"✅","(Inc)");sign=NG+"✅"
            elif vals[-1]<vals[-2]:p,s=(NR+"❌","(Dec)");sign=NR+"❌"
            else:p,s=(NY+"⚪","(Neu)");sign=NY+"⚪"
            return f"{p}{name}: {istr} {RST}{s}"
        output+=(indicator_output("OBV",obv)+"\n"+indicator_output("RSI",rsi,70,30)+"\n"+indicator_output("MFI",mfi,80,20)+"\n"+indicator_output("CCI",cci,100,-100)+"\n"+indicator_output("WR%",wr,-20,-80)+"\n")
        ap,astate=(NG+"✅"if adx_val>25 else NY+"⚪"),("(Trending)"if adx_val>25 else"(Sideways)");output+=f"{ap}ADX: {adx_val:.2f} {RST}{astate}\n"
        adi_vals=adi.tail(3).tolist();ap=NG+"✅"if adi_vals[-1]>adi_vals[-2]else NR+"❌"if adi_vals[-1]<adi_vals[-2]else NY+"⚪";atrend="(Inc)"if adi_vals[-1]>adi_vals[-2]else"(Dec)"if adi_vals[-1]<adi_vals[-2]else"(Neu)";output+=f"{ap}ADI: "+" | ".join([f"{val:.2f}"for val in adi_vals])+f" {RST}{atrend}\n"
        mom_output=(NG+"✅ Momentum"if t=="Up"else NR+"❌ Momentum"if t=="Down"else NY+"⚪ No Momentum");output+=f"{mom_output}{RST}, Strength: {ts:.2f}\n"
        sma_output=(NG+"✅ Bullish"if self.df['close'].iloc[-1]>sma20.iloc[-1]else NR+"❌ Bearish");output+=f"{sma_output}{RST} SMA (Price vs 20 SMA)\n"
        adi_signal_output=(NG+"✅ Bullish"if adi.iloc[-1]>adi.iloc[-2]else NR+"❌ Bearish");output+=f"{adi_signal_output}{RST} ADI Trend\n"
        macd_signal_output=(NG+"✅ Bullish"if macd_df['macd'].iloc[-1]>macd_df['signal'].iloc[-1]else NR+"❌ Bearish");output+=f"{macd_signal_output}{RST} MACD Crossover\n"
        psar_signal_output=(NR+"❌ Bearish"if psar_vals.iloc[-1]<self.df['close'].iloc[-1]else NG+"✅ Bullish");output+=f"{psar_signal_output}{RST} PSAR vs Price\n"
        output+=f"""\nSupport/Resistance:\nS: """+", ".join([f"{label}: ${val:.3f}"for label,val in ns])+f"""\nR: """+", ".join([f"{label}: ${val:.3f}"for label,val in nr])+f"""\nTrend: {t}, Strength: {ts:.2f}\nNext Lvl: {nl}\n"""
        self.sig=t;print(output if ts_out=="terminal"else(self.log.info(output),None)[0])
if __name__ == "__main__":
    logger=sl("ScalperBot");symbol="BTCUSDT";interval="15"
    df_klines=fk(symbol,interval,limit=100,l=logger)
    if not df_klines.empty:
        current_price=fcp(symbol,logger)
        if current_price:TA(df_klines,logger,CONFIG,symbol,interval).analyze(current_price,"terminal")
        else:logger.error(f"{NR}Failed to get current price for {symbol}{RST}")
    else:logger.error(f"{NR}Failed to fetch Kline data for {symbol}{RST}")
