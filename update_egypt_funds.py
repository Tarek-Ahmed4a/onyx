import pandas as pd
from pathlib import Path

def update_egypt_funds():
    # Funds transcribed from the provided images
    egypt_funds = [
        {"symbol": "AAF.CA", "name": "صندوق افاق"},
        {"symbol": "ABR.CA", "name": "صندوق بريق"},
        {"symbol": "ADA.CA", "name": "صندوق الاهلي دهب"},
        {"symbol": "ADM.CA", "name": "صندوق دياموند"},
        {"symbol": "AEF.CA", "name": "صندوق الفنار"},
        {"symbol": "AGO.CA", "name": "صندوق جسور"},
        {"symbol": "AIS.CA", "name": "صندوق استثمار وأمان"},
        {"symbol": "ALV.CA", "name": "صندوق AZ LV"},
        {"symbol": "ASO.CA", "name": "صندوق أزيموت فرص الشريعة"},
        {"symbol": "ATD.CA", "name": "صندوق الاهلي تميز ذو التوزيع ا..."},
        {"symbol": "AZG.CA", "name": "صندوق Azimut جولد"},
        {"symbol": "AZN.CA", "name": "صندوق ازيموت ناصر"},
        {"symbol": "AZO.CA", "name": "صندوق ازيموت فرص"},
        {"symbol": "AZS.CA", "name": "صندوق AZ ادخار"},
        {"symbol": "B35.CA", "name": "صندوق بلتون بي-35"},
        {"symbol": "B70.CA", "name": "صندوق بلتون EGX70"},
        {"symbol": "BAL.CA", "name": "صندوق بلتون للاستثمار في ..."},
        {"symbol": "BCO.CA", "name": "صندوق بلتون القطاع الاسته..."},
        {"symbol": "BFA.CA", "name": "صندوق بلتون فضة"},
        {"symbol": "BFF.CA", "name": "صندوق بنك القاهره الاول"},
        {"symbol": "BFI.CA", "name": "صندوق بلتون القطاع المالي"},
        {"symbol": "BIN.CA", "name": "صندوق بلتون القطاع الصناعي"},
        {"symbol": "BMM.CA", "name": "صندوق بلتون مية مية"},
        {"symbol": "BRE.CA", "name": "صندوق بلتون القطاع العقاري"},
        {"symbol": "BSB.CA", "name": "صندوق بلتون سبائك"},
        {"symbol": "BSC.CA", "name": "صندوق بي سكيور"},
        {"symbol": "BWA.CA", "name": "صندوق بلتون وفرة"},
        {"symbol": "C20.CA", "name": "صندوق سي آي 20HD"},
        {"symbol": "CCB.CA", "name": "صندوق سي آي استهلاكي"},
        {"symbol": "CCM.CA", "name": "صندوق كايرو كابيتال مومنتم"},
        {"symbol": "CCS.CA", "name": "صندوق كايرو كابيتال ستريم"},
        {"symbol": "CEX.CA", "name": "صندوق سي آي تصدير"},
        {"symbol": "CFF.CA", "name": "صندوق سي آي مال ومدفوعا..."},
        {"symbol": "CI30.CA", "name": "صندوق مؤشر CI EGX30"},
        {"symbol": "CIP.CA", "name": "صندوق سي آي للاكتتابات الأو..."},
        {"symbol": "CMS.CA", "name": "صندوق مؤشر CI EGX33 الشري..."},
        {"symbol": "CRE.CA", "name": "صندوق سي آي عقارات وبناء"},
        {"symbol": "CTI.CA", "name": "صندوق سي آي تكنولوجيا وات..."},
        {"symbol": "CTQ.CA", "name": "صندوق سي إي ذا كوانت"},
        {"symbol": "GRA.CA", "name": "صندوق جرانيت"},
        {"symbol": "MSI.CA", "name": "صندوق مباشر فضة"},
        {"symbol": "MTF.CA", "name": "صندوق مصر للتأمين التكافلي"},
        {"symbol": "NAM.CA", "name": "صندوق بنك الكويت الوطني ال..."},
        {"symbol": "NCS.CA", "name": "صندوق سهمي 70 ان أي كابيتال"},
        {"symbol": "NMF.CA", "name": "صندوق NM أسهم شريعة"},
        {"symbol": "PCM.CA", "name": "صندوق كاشي PFI"},
        {"symbol": "PGM.CA", "name": "جي اي جي للتأمين النقدي للسي..."},
        {"symbol": "T70.CA", "name": "صندوق ثاندر T70"},
        {"symbol": "ZEM.CA", "name": "صندوق زالدي المصري"},
        {"symbol": "ZST.CA", "name": "صندوق زالدي ستار"},
    ]
    
    output_dir = Path("ticker_data")
    output_dir.mkdir(exist_ok=True)
    
    df = pd.DataFrame(egypt_funds)
    # Add metadata columns for consistency
    df["exchange"] = "EGX"
    df["type"] = "fund"
    df["specs"] = "mutual_fund"
    
    df.to_csv(output_dir / "EGX_funds.csv", index=False, encoding="utf-8-sig")
    print(f"Updated EGX_funds.csv with {len(df)} funds.")

def remove_qatar_data():
    output_dir = Path("ticker_data")
    qatar_files = list(output_dir.glob("*QATAR*"))
    for f in qatar_files:
        f.unlink()
        print(f"Deleted {f}")

if __name__ == "__main__":
    update_egypt_funds()
    remove_qatar_data()
    
    # Also update all_funds.csv
    output_dir = Path("ticker_data")
    all_funds = []
    for f in output_dir.glob("*_funds.csv"):
        if "QATAR" not in f.name and "all_funds" not in f.name:
            df = pd.read_csv(f)
            df["market"] = f.name.split("_")[0].lower()
            all_funds.append(df)
            
    if all_funds:
        combined_df = pd.concat(all_funds, ignore_index=True)
        combined_df.to_csv(output_dir / "all_funds.csv", index=False, encoding="utf-8-sig")
        print(f"Updated all_funds.csv with {len(combined_df)} funds.")
