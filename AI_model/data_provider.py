from tvDatafeed import TvDatafeed, Interval # type: ignore
import yfinance as yf
import pandas as pd
import os

class DataProvider:
    """
    Role: Fetch raw market data and news.
    Source: Yahoo Finance with TradingView Fallback.
    """
    
    def __init__(self):
        self.tv = TvDatafeed()

    def get_history(self, ticker: str, period: str = "1y", interval: str = "1d") -> pd.DataFrame:
        """
        Fetch historical price data (OHLCV).
        """
        print(f"Fetching history for {ticker}...")
        
        # 1. Try Yahoo Finance
        try:
            data = yf.download(ticker, period=period, interval=interval, progress=False)
            if not data.empty and data['Close'].iloc[-1] > 0:
                # Flatten MultiIndex if necessary
                if isinstance(data.columns, pd.MultiIndex):
                    data.columns = data.columns.get_level_values(0)
                return data
        except Exception as e:
            print(f"Yahoo Finance failed for {ticker}: {e}")

        # 2. Fallback to TradingView
        print(f"Falling back to TradingView for {ticker}...")
        try:
            # Map ticker to TV symbol and exchange
            symbol = ticker
            exchange = 'EGX' # Default
            
            if ticker.endswith('.SR') or ticker.isdigit():
                exchange = 'TADAWUL'
                symbol = ticker.replace('.SR', '')
            elif ticker.endswith('.DU') or ticker.endswith('.AE'):
                exchange = 'DFM'
                symbol = ticker.replace('.DU', '').replace('.AE', '')
            elif ticker.endswith('.AD'):
                exchange = 'ADX'
                symbol = ticker.replace('.AD', '')
            elif ticker.endswith('.CA'):
                exchange = 'EGX'
                symbol = ticker.replace('.CA', '')
            
            # Map period to n_bars
            period_map = {"1mo": 30, "3mo": 90, "1y": 260, "5y": 1300, "10y": 2600}
            n_bars = period_map.get(period, 260)
            
            tv_data = self.tv.get_hist(symbol=symbol, exchange=exchange, interval=Interval.in_daily, n_bars=n_bars)
            
            if tv_data is not None and not tv_data.empty:
                tv_data.rename(columns={
                    'open': 'Open', 'high': 'High', 'low': 'Low', 
                    'close': 'Close', 'volume': 'Volume'
                }, inplace=True)
                return tv_data
                
        except Exception as e:
            print(f"TradingView also failed for {ticker}: {e}")

        return pd.DataFrame()

    def get_news(self, ticker: str) -> list:
        """
        Fetch latest news for the ticker.
        """
        try:
            t = yf.Ticker(ticker)
            return t.news
        except Exception as e:
            print(f"Error fetching news for {ticker}: {e}")
            return []
