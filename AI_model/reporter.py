import google.generativeai as genai
import os
from dotenv import load_dotenv

load_dotenv()

class Reporter:
    """
    Role: Professional Advisory Report Generator (Gemini 3.1 Pro).
    Translates numbers and decisions into a human-readable report.
    """
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            genai.configure(api_key=self.api_key)
            # Use Pro for better writing quality
            self.model = genai.GenerativeModel('gemini-3.1-pro-preview')
        else:
            self.model = None
            print("Warning: GEMINI_API_KEY not found. Reports will be plain text.")

    def generate(self, ticker: str, decision: str, tech_prob: float, sentiment: float, news: str) -> str:
        """
        Input: Decision context and data.
        Output: Premium Markdown formatted professional report.
        """
        if not self.model:
            return f"Advisory Report for {ticker}:\nFinal Decision: {decision}\nTechnical Probability: {tech_prob:.2f}\nSentiment: {sentiment:.2f}"
            
        prompt = f"""
        You are 'Onyx AI Advisor', the most sophisticated financial expert in the Middle East.
        Write a premium, structured investment advisory report for '{ticker}'.
        
        Context Data:
        - Recommendation: {decision}
        - Technical Probability (AI): {tech_prob*100:.1f}%
        - Sentiment Score: {sentiment:.2f} (where -1 is Panic, 0 is Neutral, 1 is Euphoria)
        - News Feed Summary: {news}
        
        Report Requirements:
        1. Language: Use professional Arabic mixed with smart Egyptian financial dialect (Premium and sophisticated).
        2. Format: Use rich Markdown (bolding, lists, emojis).
        3. Structure:
           ## 🏛️ الملخص التنفيذي
           (A one-sentence powerful summary of the situation)
           
           ## 📈 التحليل الفني العميق
           (Explain what the LightGBM model saw in the history of the stock. Mention the {tech_prob*100:.1f}% confidence)
           
           ## 📰 نبض السوق والأخبار
           (Analyze the news provided: {news}. Mention how the sentiment score of {sentiment:.2f} impacts the stock)
           
           ## 🎯 التوصية النهائية
           (Bold recommendation: {decision}. Use specific target levels or stop losses if applicable in a professional way)
           
           ---
           *إخلاء مسؤولية: هذا التحليل يعتمد على نماذج الذكاء الاصطناعي ولا يعتبر نصيحة مالية مباشرة.*
        
        Style: Do not use placeholders. Be direct, impressive, and No-BS.
        """
        
        # Internal retry logic with key rotation
        keys_to_try = [os.getenv(f"GEMINI_API_KEY_{i}") for i in range(1, 10) if os.getenv(f"GEMINI_API_KEY_{i}")]
        if os.getenv("GEMINI_API_KEY") and os.getenv("GEMINI_API_KEY") not in keys_to_try:
            keys_to_try.insert(0, os.getenv("GEMINI_API_KEY"))
            
        for key in keys_to_try:
            try:
                genai.configure(api_key=key)
                temp_model = genai.GenerativeModel('gemini-3.1-pro-preview')
                response = temp_model.generate_content(prompt)
                return response.text
            except Exception as e:
                if "429" in str(e):
                    continue
                return f"❌ خطأ في توليد التقرير: {e}"
        
        return "❌ عذراً، تم استهلاك حصة الـ API لجميع المفاتيح المتاحة حالياً."

if __name__ == "__main__":
    # Test
    r = Reporter()
    print(r.generate_report("AAPL", "BUY", {"prob": 0.75, "rsi": 28, "macd": "Bullish Crossover"}, 0.4))
