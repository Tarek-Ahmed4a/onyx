import os
from dotenv import load_dotenv

load_dotenv()

# Get all available keys
GEMINI_KEYS = []
for i in range(1, 10):
    key = os.getenv(f"GEMINI_API_KEY_{i}")
    if key:
        GEMINI_KEYS.append(key)
if os.getenv("GEMINI_API_KEY"):
    GEMINI_KEYS.insert(0, os.getenv("GEMINI_API_KEY"))

# Use the first one for now
if GEMINI_KEYS:
    os.environ["GEMINI_API_KEY"] = GEMINI_KEYS[0]

from data_provider import DataProvider
from technical_processor import TechnicalProcessor
from technical_model import TechnicalModel
from sentiment_analyzer import SentimentAnalyzer
from decision_engine import DecisionEngine
from reporter import Reporter

class OnyxAI:
    """
    Role: Orchestrate the full AI Pipeline.
    """
    
    def __init__(self):
        # Global instances (initially empty, will be set per request)
        self.data_provider = DataProvider()
        self.processor = TechnicalProcessor()
        self.sentiment_analyzer = SentimentAnalyzer()
        self.reporter = Reporter()
        
    def _detect_market(self, ticker: str) -> str:
        """Determines if the ticker is Egyptian (EGX), Saudi (KSA), or UAE."""
        t_upper = ticker.upper()
        if t_upper.endswith('.SR') or (t_upper.isdigit() and len(t_upper) >= 4) or t_upper.startswith('TADAWUL:'):
            return "KSA"
        if t_upper.endswith('.AE') or t_upper.endswith('.DU') or t_upper.endswith('.AD') or t_upper.startswith('DFM:') or t_upper.startswith('ADX:'):
            return "UAE"
        return "EGX"

    def run_analysis(self, ticker: str):
        market = self._detect_market(ticker)
        print(f"Starting analysis for {ticker} (Market: {market})...")
        
        # Load market-specific models
        tech_model = TechnicalModel(market=market)
        decision_engine = DecisionEngine(market=market)
        
        # 1. Fetch Data
        df = self.data_provider.get_history(ticker)
        if df is None or df.empty:
            print(f"Failed to fetch data for {ticker}")
            return None
            
        # 2. Process Technical Indicators
        features_df = self.processor.calculate_indicators(df)
        
        # 3. Technical Inference (LightGBM)
        tech_prob = tech_model.predict(features_df)
        
        # 4. Sentiment Analysis (Gemini Flash)
        sentiment_score, news_summary = self.sentiment_analyzer.analyze(ticker)
        
        # 5. Final Decision (CatBoost)
        decision = decision_engine.get_decision(tech_prob, sentiment_score)
        
        # 6. Generate Report (Gemini Pro)
        report = self.reporter.generate(
            ticker=ticker,
            decision=decision,
            tech_prob=tech_prob,
            sentiment=sentiment_score,
            news=news_summary
        )
        
        return {
            "ticker": ticker,
            "market": market,
            "decision": decision,
            "tech_prob": tech_prob,
            "sentiment_score": sentiment_score,
            "report": report
        }

if __name__ == "__main__":
    import sys
    import codecs
    if sys.platform == "win32":
        sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
        
    onyx = OnyxAI()
    # Test EGX
    print(onyx.run_analysis("COMI.CA"))
    # Test KSA
    # print(onyx.run_analysis("2222.SR"))
