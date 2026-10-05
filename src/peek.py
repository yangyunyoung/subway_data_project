import glob

path = sorted(glob.glob("data/raw/CARD_SUBWAY_MONTH_*.csv"))[0]

for enc in ("utf-8", "cp949"):
    try:
        with open(path, encoding=enc) as f:
            lines = [next(f) for _ in range(4)]
        print("인코딩:", enc)
        break
    except UnicodeDecodeError:
        continue

for line in lines:
    print(repr(line))