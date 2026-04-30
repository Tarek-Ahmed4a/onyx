import lightgbm as lgb
import os
import pandas as pd
import yfinance as yf

class TechnicalModel:
    """
    Role: Analyze technical indicators using LightGBM.
    Supports: EGX and TADAWUL.
    """
    
    def __init__(self, market="EGX"):
        self.market = market
        self.model_path = f"models/lgbm_{market.lower()}.txt"
        self.model = None
        self._load_model()
        
    def _load_model(self):
        if os.path.exists(self.model_path):
            self.model = lgb.Booster(model_file=self.model_path)
            # print(f"Loaded {self.market} model from {self.model_path}")
        else:
            print(f"Warning: {self.market} model not found. Using Mock mode.")

    def predict(self, features_df: pd.DataFrame) -> float:
        """
        Predicts the probability of price increase.
        """
        if self.model:
            # Select relevant features
            cols = ['RSI_14', 'RSI_21', 'MACD_Diff', 'Dist_EMA_20', 'BB_Width']
            
            # Add Brent Oil if Saudi or UAE
            if self.market in ["KSA", "UAE"]:
                # If Oil_Trend is missing in features_df, fetch it
                if 'Oil_Trend' not in features_df.columns:
                    try:
                        oil = yf.download("BZ=F", period="5d", progress=False)
                        if isinstance(oil.columns, pd.MultiIndex):
                            oil = oil.xs('BZ=F', level=1, axis=1)
                        oil_change = oil['Close'].pct_change().iloc[-1]
                        features_df['Oil_Trend'] = oil_change
                    except:
                        features_df['Oil_Trend'] = 0
                cols.append('Oil_Trend')
                
            X = features_df[cols].tail(1)
            prob = self.model.predict(X)[0]
            return float(prob)
        else:
            # Mock Logic (Simple RSI based)
            rsi = features_df['RSI_14'].iloc[-1]
            if rsi < 30: return 0.85
            if rsi > 70: return 0.15
            return 0.50
