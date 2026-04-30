import catboost
import lightgbm
import pandas as pd
import numpy as np

def test_imports():
    print(f"CatBoost version: {catboost.__version__}")
    print(f"LightGBM version: {lightgbm.__version__}")
    
    # Simple check for CatBoost
    try:
        model = catboost.CatBoostClassifier(iterations=2, depth=2, learning_rate=1, loss_function='Logloss', verbose=False)
        train_data = np.random.randint(0, 100, size=(10, 3))
        train_labels = np.random.randint(0, 2, size=(10))
        model.fit(train_data, train_labels)
        print("CatBoost: Basic fit test passed!")
    except Exception as e:
        print(f"CatBoost: Basic fit test failed with error: {e}")

    # Simple check for LightGBM
    try:
        train_data = np.random.randint(0, 100, size=(10, 3))
        train_labels = np.random.randint(0, 2, size=(10))
        train_ds = lightgbm.Dataset(train_data, label=train_labels)
        params = {'objective': 'binary', 'metric': 'binary_logloss', 'verbose': -1}
        gbm = lightgbm.train(params, train_ds, num_boost_round=2)
        print("LightGBM: Basic fit test passed!")
    except Exception as e:
        print(f"LightGBM: Basic fit test failed with error: {e}")

if __name__ == "__main__":
    test_imports()
