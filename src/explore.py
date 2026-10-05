import glob
import os
import pandas as pd

files = sorted(glob.glob("data/raw/CARD_SUBWAY_MONTH_*.csv"))
print("파일 수:", len(files))


def read_csv_auto(path):
    try:
        return pd.read_csv(path, encoding="utf-8")
    except UnicodeDecodeError:
        return pd.read_csv(path, encoding="cp949")


frames = []
for f in files:
    d = read_csv_auto(f)
    d["source_file"] = os.path.basename(f)   # 어느 파일에서 왔는지 표시
    print(os.path.basename(f), d.shape)
    frames.append(d)

# 월별 파일의 컬럼명이 서로 같은지 확인
base_cols = list(frames[0].columns)
for f, d in zip(files, frames):
    if list(d.columns) != base_cols:
        print("컬럼이 다른 파일:", os.path.basename(f), list(d.columns))

df = pd.concat(frames, ignore_index=True)

print("\n=== 전체 ===")
print(df.shape)
print(df.head())
print(df.dtypes)
print(df.isna().sum())
print("중복 행:", df.duplicated().sum())