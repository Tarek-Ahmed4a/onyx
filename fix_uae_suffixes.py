import pandas as pd
from pathlib import Path

def fix_uae_suffixes():
    output_dir = Path("ticker_data")
    
    # DFM -> .DU
    dfm_path = output_dir / "DFM_tickers.csv"
    if dfm_path.exists():
        df = pd.read_csv(dfm_path)
        df["symbol"] = df["symbol"].apply(lambda x: f"{x}.DU" if not str(x).endswith(".DU") else x)
        df.to_csv(dfm_path, index=False, encoding="utf-8-sig")
        print("Updated DFM suffixes to .DU")
        
    # ADX -> .AD
    adx_path = output_dir / "ADX_tickers.csv"
    if adx_path.exists():
        df = pd.read_csv(adx_path)
        df["symbol"] = df["symbol"].apply(lambda x: f"{x}.AD" if not str(x).endswith(".AD") else x)
        df.to_csv(adx_path, index=False, encoding="utf-8-sig")
        print("Updated ADX suffixes to .AD")
        
    # NASDAQ Dubai -> .DU (often traded on DFM platform)
    nasdaq_path = output_dir / "NASDAQDUBAI_tickers.csv"
    if nasdaq_path.exists():
        df = pd.read_csv(nasdaq_path)
        df["symbol"] = df["symbol"].apply(lambda x: f"{x}.DU" if not str(x).endswith(".DU") else x)
        df.to_csv(nasdaq_path, index=False, encoding="utf-8-sig")
        print("Updated NASDAQ Dubai suffixes to .DU")

if __name__ == "__main__":
    fix_uae_suffixes()
