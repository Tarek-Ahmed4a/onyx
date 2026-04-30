import catboost as cb
import pandas as pd
import numpy as np
import os

class DecisionTrainer:
    """
    Role: Train CatBoost (Final Judge) for specific markets.
    """
    
    def __init__(self, market="EGX"):
        self.market = market
        self.model_path = f"models/catboost_{market.lower()}.cbm"
        
    def train(self):
        print(f"Training Decision Engine (CatBoost) for {self.market}...")
        
        num_samples = 5000
        tech_prob = np.random.uniform(0.1, 0.9, num_samples)
        sentiment_score = np.random.uniform(-1, 1, num_samples)
        
        # Rule-based Target Generation
        target = []
        for tp, ss in zip(tech_prob, sentiment_score):
            score = (tp * 0.6) + ((ss + 1) / 2 * 0.4)
            if score > 0.65:
                target.append(2) # BUY
            elif score < 0.35:
                target.append(0) # SELL
            else:
                target.append(1) # HOLD
                
        df = pd.DataFrame({
            'tech_prob': tech_prob,
            'sentiment_score': sentiment_score,
            'target': target
        })
        
        X = df[['tech_prob', 'sentiment_score']]
        y = df['target']
        
        model = cb.CatBoostClassifier(
            iterations=200,
            depth=6,
            learning_rate=0.1,
            loss_function='MultiClass',
            verbose=False
        )
        
        model.fit(X, y)
        
        os.makedirs('models', exist_ok=True)
        model.save_model(self.model_path)
        print(f"CatBoost model trained and saved to {self.model_path}")

if __name__ == "__main__":
    for m in ["EGX", "KSA", "UAE"]:
        DecisionTrainer(market=m).train()
