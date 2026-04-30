import catboost as cb
import os
import pandas as pd

class DecisionEngine:
    """
    Role: Combine Technical + Sentiment into a final Recommendation.
    """
    
    def __init__(self, market="EGX"):
        self.market = market
        self.model_path = f"models/catboost_{market.lower()}.cbm"
        self.model = None
        self._load_model()
        
    def _load_model(self):
        if os.path.exists(self.model_path):
            self.model = cb.CatBoostClassifier()
            self.model.load_model(self.model_path)
        else:
            print(f"Warning: {self.market} Decision model not found. Using Mock.")

    def get_decision(self, tech_prob: float, sentiment_score: float) -> str:
        """
        Final Recommendation Logic.
        """
        if self.model:
            input_data = pd.DataFrame({
                'tech_prob': [tech_prob],
                'sentiment_score': [sentiment_score]
            })
            pred = self.model.predict(input_data)[0][0]
            
            mapping = {2: "BUY", 1: "HOLD", 0: "SELL"}
            return mapping.get(pred, "HOLD")
        else:
            # Fallback Logic
            score = (tech_prob * 0.6) + ((sentiment_score + 1) / 2 * 0.4)
            if score > 0.65: return "BUY"
            if score < 0.35: return "SELL"
            return "HOLD"
