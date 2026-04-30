import google.generativeai as genai
import os
import json
from dotenv import load_dotenv

load_dotenv()

class SentimentAnalyzer:
    """
    Role: News Sentiment Analysis (Gemini 3.1 Flash Lite).
    Converts news text into a sentiment score.
    """
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            genai.configure(api_key=self.api_key)
            self.model = genai.GenerativeModel('gemini-3.1-flash-lite-preview')
        else:
            self.model = None
            print("Warning: GEMINI_API_KEY not found. Sentiment analysis will be mocked.")

    def analyze(self, ticker: str, news_items: list = None) -> tuple:
        """
        Input: Ticker and optional list of news items.
        Output: (Sentiment score -1.0 to 1.0, News summary string).
        """
        # Mocking news fetch for now if not provided
        if not news_items:
            news_items = [{"title": f"No recent news for {ticker}"}]
            
        news_text = "\n".join([f"- {item.get('title', '')}" for item in news_items[:5]])
        
        if not self.model:
            return 0.0, news_text
            
        prompt = f"""
        Analyze the sentiment of the following financial news headlines for {ticker}.
        Return a JSON object with:
        1. 'sentiment_score': float between -1.0 and 1.0.
        2. 'summary': a very short one-sentence summary of the news impact.
        
        News:
        {news_text}
        
        JSON:
        """
        
        try:
            response = self.model.generate_content(prompt)
            content = response.text.strip()
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            
            data = json.loads(content)
            return float(data.get("sentiment_score", 0.0)), data.get("summary", news_text)
        except Exception as e:
            print(f"Error in Gemini Sentiment Analysis: {e}")
            return 0.0, news_text

if __name__ == "__main__":
    # Test
    sa = SentimentAnalyzer()
    dummy_news = [{"title": "Company reports record profits and expansion plan"}, {"title": "Market optimistic about new product launch"}]
    print(f"Sentiment Score: {sa.analyze_news(dummy_news)}")
