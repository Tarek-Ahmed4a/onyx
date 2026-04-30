from pipeline import OnyxAI
import sys
import os

def test_full_pipeline():
    print("Testing Onyx AI Pipeline...")
    
    # Initialize the pipeline
    onyx = OnyxAI()
    
    # Test with a known ticker
    ticker = "AAPL"
    result = onyx.run_analysis(ticker)
    
    if result:
        print("\nPipeline test SUCCESS!")
        print(f"Ticker: {result['ticker']}")
        print(f"Decision: {result['decision']}")
        print(f"Tech Prob: {result['tech_prob']:.2f}")
        print(f"Sentiment: {result['sentiment_score']:.2f}")
        print("\n--- Sample Report (First 200 chars) ---")
        print(result['report'][:200] + "...")
        return True
    else:
        print("\nPipeline test FAILED!")
        return False

if __name__ == "__main__":
    success = test_full_pipeline()
    if not success:
        sys.exit(1)
