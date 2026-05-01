import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY_1")
print(f"Using key: {api_key[:10]}...")
genai.configure(api_key=api_key)
model = genai.GenerativeModel('gemini-pro')

try:
    response = model.generate_content("Say hello in Arabic")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
