import sys
import os
sys.stdout.reconfigure(encoding='utf-8')

# Append backend to path to allow importing
sys.path.append(os.path.dirname(os.path.abspath(__file__)) + "/../")

from backend.app import _fetch_mubasher_price, _fetch_single_ticker_aggressive
print("Mubasher scraper price for 4330.SR:", _fetch_mubasher_price('4330.SR'))
