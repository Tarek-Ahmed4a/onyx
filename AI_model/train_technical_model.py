import pandas as pd
import numpy as np
import lightgbm as lgb
from ta.momentum import RSIIndicator
from ta.trend import MACD, EMAIndicator
from ta.volatility import BollingerBands
import os

class TechnicalTrainer:
    """
    Role: Train LightGBM on historical data (EGX, KSA, or UAE).
    """
    
    def __init__(self, market="EGX"):
        self.market = market
        self.data_path = f'{market}_10_Years_Data.csv'
        self.model_name = f'lgbm_{market.lower()}.txt'
        
    def prepare_features(self, df):
        print(f"Engineering features for {self.market}...")
        df['Date'] = pd.to_datetime(df['Date'], format='mixed', utc=True)
        df = df.sort_values(['Symbol', 'Date'])
        
        processed_frames = []
        for symbol, group in df.groupby('Symbol'):
            if len(group) < 50: continue
            
            group = group.copy()
            group['RSI_14'] = RSIIndicator(close=group['close'], window=14).rsi()
            group['RSI_21'] = RSIIndicator(close=group['close'], window=21).rsi()
            
            macd = MACD(close=group['close'])
            group['MACD_Diff'] = macd.macd_diff()
            
            group['EMA_20'] = EMAIndicator(close=group['close'], window=20).ema_indicator()
            group['Dist_EMA_20'] = (group['close'] - group['EMA_20']) / group['EMA_20']
            
            bb = BollingerBands(close=group['close'])
            group['BB_Width'] = (bb.bollinger_hband() - bb.bollinger_lband()) / bb.bollinger_mavg()
            
            # Special Feature for KSA/UAE: Brent Oil Correlation
            if 'Brent_Oil' in group.columns:
                group['Oil_Trend'] = group['Brent_Oil'].pct_change(5) 
            
            # Target
            group['Target'] = (group['close'].shift(-5) > group['close'] * 1.03).astype(int)
            processed_frames.append(group)
            
        final_df = pd.concat(processed_frames).dropna()
        return final_df

    def train(self):
        if not os.path.exists(self.data_path):
            print(f"Error: {self.data_path} not found.")
            return
            
        df = pd.read_csv(self.data_path)
        data = self.prepare_features(df)
        
        features = ['RSI_14', 'RSI_21', 'MACD_Diff', 'Dist_EMA_20', 'BB_Width']
        if 'Oil_Trend' in data.columns:
            features.append('Oil_Trend')
            
        X = data[features]
        y = data['Target']
        
        split_idx = int(len(X) * 0.8)
        X_train, X_test = X.iloc[:split_idx], X.iloc[split_idx:]
        y_train, y_test = y.iloc[:split_idx], y.iloc[split_idx:]
        
        print(f"Training {self.market} model on {len(X_train)} samples...")
        
        train_data = lgb.Dataset(X_train, label=y_train)
        test_data = lgb.Dataset(X_test, label=y_test, reference=train_data)
        
        params = {
            'objective': 'binary',
            'metric': 'binary_logloss',
            'boosting_type': 'gbdt',
            'verbose': -1
        }
        
        model = lgb.train(params, train_data, num_boost_round=100, valid_sets=[test_data])
        
        os.makedirs('models', exist_ok=True)
        model.save_model(f'models/{self.model_name}')
        print(f"Model saved to models/{self.model_name}")

if __name__ == "__main__":
    # Train EGX
    if os.path.exists('EGX_10_Years_Data.csv'):
        TechnicalTrainer(market="EGX").train()
    
    # Train KSA
    if os.path.exists('KSA_10_Years_Data.csv'):
        TechnicalTrainer(market="KSA").train()
        
    # Train UAE
    if os.path.exists('UAE_10_Years_Data.csv'):
        TechnicalTrainer(market="UAE").train()
