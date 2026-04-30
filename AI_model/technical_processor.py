import pandas as pd
from ta import add_all_ta_features
from ta.utils import dropna
from ta.momentum import RSIIndicator
from ta.trend import MACD
from ta.volatility import BollingerBands

class TechnicalProcessor:
    """
    Role: Mathematical Blender.
    Processes raw OHLCV data into technical indicators.
    """
    
    @staticmethod
    def calculate_indicators(df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculates key technical indicators: RSI, MACD, Bollinger Bands, etc.
        """
        if df.empty:
            return df
            
        # Ensure we have clean data
        df = df.copy()
        
        # Calculate RSI
        rsi_21 = RSIIndicator(close=df['Close'], window=21)
        df['RSI_21'] = rsi_21.rsi()
        
        rsi_14 = RSIIndicator(close=df['Close'], window=14)
        df['RSI_14'] = rsi_14.rsi()
        
        # Calculate MACD
        macd = MACD(close=df['Close'])
        df['MACD'] = macd.macd()
        df['MACD_Signal'] = macd.macd_signal()
        df['MACD_Diff'] = macd.macd_diff()
        
        # Calculate Bollinger Bands
        bb = BollingerBands(close=df['Close'])
        df['BB_High'] = bb.bollinger_hband()
        df['BB_Low'] = bb.bollinger_lband()
        df['BB_Mid'] = bb.bollinger_mavg()
        df['BB_Width'] = (df['BB_High'] - df['BB_Low']) / df['BB_Mid']
        
        # EMA
        from ta.trend import EMAIndicator
        df['EMA_20'] = EMAIndicator(close=df['Close'], window=20).ema_indicator()
        df['Dist_EMA_20'] = (df['Close'] - df['EMA_20']) / df['EMA_20']
        
        # Add some custom logic for volatility
        df['Volatility'] = df['Close'].pct_change().rolling(window=20).std()
        
        # Drop NaN values created by indicators
        return df.dropna()

if __name__ == "__main__":
    # Test with dummy data
    import numpy as np
    dates = pd.date_range('2023-01-01', periods=100)
    data = pd.DataFrame({
        'Open': np.random.randn(100).cumsum() + 100,
        'High': np.random.randn(100).cumsum() + 105,
        'Low': np.random.randn(100).cumsum() + 95,
        'Close': np.random.randn(100).cumsum() + 100,
        'Volume': np.random.randint(100, 1000, 100)
    }, index=dates)
    
    tp = TechnicalProcessor()
    processed = tp.calculate_indicators(data)
    print(processed.columns)
    print(processed.tail())
