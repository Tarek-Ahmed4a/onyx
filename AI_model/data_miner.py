import pandas as pd
import yfinance as yf
from tvDatafeed import TvDatafeed, Interval
import time
import os
import sqlite3
import sys

# Ensure stdout handles UTF-8
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())

class MarketDataMiner:
    """
    Role: Fetch 10 years of historical data for EGX, KSA, or UAE.
    """
    
    def __init__(self, db_path="ticker_data/tickers.db"):
        self.tv = TvDatafeed()
        self.db_path = db_path
        
    def get_symbols(self, market="EGX"):
        """Extracts symbols for a specific market from the local database."""
        if not os.path.exists(self.db_path):
            print(f"Warning: {self.db_path} not found.")
            return []
            
        conn = sqlite3.connect(self.db_path)
        symbols_with_exchange = []
        
        try:
            if market == "EGX":
                df = pd.read_sql("SELECT symbol FROM egx_tickers", conn)
                symbols_with_exchange = [(s.replace('.CA', ''), 'EGX', '.CA') for s in df['symbol'].tolist()]
            elif market == "KSA":
                df = pd.read_sql("SELECT symbol FROM ksa_tickers", conn)
                symbols_with_exchange = [(s.replace('.SR', ''), 'TADAWUL', '.SR') for s in df['symbol'].tolist()]
            elif market == "UAE":
                # Dubai
                df_dfm = pd.read_sql("SELECT symbol FROM dfm_tickers", conn)
                for s in df_dfm['symbol'].tolist():
                    clean = s.replace('.DU', '').replace('.AD', '').replace('.AE', '')
                    symbols_with_exchange.append((clean, 'DFM', '.AE'))
                # Abu Dhabi
                df_adx = pd.read_sql("SELECT symbol FROM adx_tickers", conn)
                for s in df_adx['symbol'].tolist():
                    clean = s.replace('.DU', '').replace('.AD', '').replace('.AE', '')
                    symbols_with_exchange.append((clean, 'ADX', '.AE'))
                
            conn.close()
            return symbols_with_exchange
        except Exception as e:
            print(f"Error reading DB: {e}")
            conn.close()
            return []

    def fetch_brent_oil(self, n_bars=2600):
        print("Fetching Brent Oil (BZ=F) data...")
        try:
            oil = yf.download("BZ=F", period="10y", progress=False)
            if isinstance(oil.columns, pd.MultiIndex):
                oil = oil.xs('BZ=F', level=1, axis=1)
            oil = oil[['Close']].rename(columns={'Close': 'Brent_Oil'})
            return oil
        except Exception as e:
            print(f"Error fetching Brent Oil: {e}")
            return pd.DataFrame()

    def fetch_market_data(self, symbols_info, market="EGX", n_bars=2600):
        all_data = []
        print(f"Starting data mining for {market} ({len(symbols_info)} symbols)...")
        
        # Fetch Brent Oil for KSA and UAE
        brent_df = pd.DataFrame()
        if market in ["KSA", "UAE"]:
            brent_df = self.fetch_brent_oil(n_bars)

        for symbol, tv_exchange, yf_suffix in symbols_info:
            print(f"[{market}:{tv_exchange}] Fetching {symbol}...", end=" ", flush=True)
            try:
                # 1. Try TradingView
                df = self.tv.get_hist(symbol=symbol, exchange=tv_exchange, interval=Interval.in_daily, n_bars=n_bars)
                
                if df is not None and not df.empty:
                    df.reset_index(inplace=True)
                    df.rename(columns={'datetime': 'Date', 'symbol': 'Symbol'}, inplace=True)
                    df['Source'] = 'TradingView'
                else:
                    raise ValueError("Empty from TV")
                    
            except Exception:
                # 2. Fallback to Yahoo Finance
                try:
                    yf_symbol = f"{symbol}{yf_suffix}"
                    ticker = yf.Ticker(yf_symbol)
                    df = ticker.history(period="10y")
                    
                    if not df.empty:
                        df.reset_index(inplace=True)
                        df['Symbol'] = f"{tv_exchange}:{symbol}"
                        df['Source'] = 'YahooFinance'
                        df.rename(columns={
                            'Open': 'open', 'High': 'high', 'Low': 'low', 
                            'Close': 'close', 'Volume': 'volume'
                        }, inplace=True)
                        df = df[['Date', 'Symbol', 'open', 'high', 'low', 'close', 'volume', 'Source']]
                    else:
                        print(f"Failed")
                        continue
                except Exception as e2:
                     print(f"Error: {e2}")
                     continue
            
            # Merge Brent Oil if available
            if not brent_df.empty:
                df['Date_only'] = pd.to_datetime(df['Date'], utc=True).dt.date
                brent_df_copy = brent_df.copy()
                brent_df_copy.index = pd.to_datetime(brent_df_copy.index, utc=True).date
                brent_df_copy = brent_df_copy[~brent_df_copy.index.duplicated(keep='first')]
                
                df = df.merge(brent_df_copy, left_on='Date_only', right_index=True, how='left')
                df.drop(columns=['Date_only'], inplace=True)
                df['Brent_Oil'] = df['Brent_Oil'].ffill().bfill()

            all_data.append(df)
            print(f"Success ({len(df)} rows)")
            time.sleep(1) 
            
        if all_data:
            final_df = pd.concat(all_data, ignore_index=True)
            output_file = f'{market}_10_Years_Data.csv'
            final_df.to_csv(output_file, index=False)
            print(f"\nSaved to {output_file}. Total: {len(final_df)}")
            
if __name__ == "__main__":
    miner = MarketDataMiner()
    
    # 1. Mining UAE
    uae_symbols = miner.get_symbols("UAE")
    if uae_symbols:
        miner.fetch_market_data(uae_symbols, market="UAE")
    
    # 2. Mining KSA
    ksa_symbols = miner.get_symbols("KSA")
    if ksa_symbols:
        miner.fetch_market_data(ksa_symbols, market="KSA")
        
    # 3. Mining EGX
    egx_symbols = miner.get_symbols("EGX")
    if egx_symbols:
        miner.fetch_market_data(egx_symbols, market="EGX")
