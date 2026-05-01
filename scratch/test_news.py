import requests
from bs4 import BeautifulSoup

def test_egx_news(ticker_symbol):
    market = "EGX"
    clean_sym = ticker_symbol.upper().split('.')[0]
    # Simple logic check
    if ".SR" in ticker_symbol.upper(): market = "TDWL"
    elif ".AD" in ticker_symbol.upper(): market = "ADX"
    elif ".DU" in ticker_symbol.upper(): market = "DFM"
    
    url = f"https://www.mubasher.info/markets/{market}/stocks/{clean_sym}/news"
    print(f"Testing URL: {url}")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            # The selector in app.py was articles = soup.find_all('div', class_='md:w-2/3')
            # Let's see if we find anything
            articles = soup.find_all('div', class_='md:w-2/3')
            print(f"Found {len(articles)} articles.")
            for i, article in enumerate(articles[:3]):
                title_tag = article.find('a')
                if title_tag:
                    print(f"{i+1}. {title_tag.get_text(strip=True)}")
        else:
            print(f"Failed with status: {response.status_code}")
    except Exception as e:
        print(f"Error: {e}")

print("--- Testing Egypt News (COMI.CA) ---")
test_egx_news("COMI.CA")
print("\n--- Testing Saudi News (1120.SR) ---")
test_egx_news("1120.SR")
