import glob
import os

import pandas as pd
from sqlalchemy import create_engine, text

DB_USER = os.getenv("DB_USER", "airflow")
DB_PASSWORD = os.getenv("DB_PASSWORD", "airflow")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5433")
DB_NAME = os.getenv("DB_NAME", "subway_db")

engine = create_engine(
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# CSV의 한글 컬럼명 → DB 컬럼명
COLUMN_MAP = {
    "사용일자": "use_date",
    "노선명": "line_name",
    "역명": "station_name",
    "승차총승객수": "boarding_cnt",
    "하차총승객수": "alighting_cnt",
    "등록일자": "registered_date",
}


def read_csv_auto(path):
    # index_col=False: 데이터 줄 끝에 빈 칸이 하나 더 있어서, 컬럼이 한 칸씩 밀리는 것을 방지
    # 날짜는 문자로 읽기: 숫자로 읽으면 20260301이 정수로 바뀜
    kwargs = dict(index_col=False, dtype={"사용일자": str, "등록일자": str})
    try:
        return pd.read_csv(path, encoding="utf-8-sig", **kwargs)
    except UnicodeDecodeError:
        # utf-8이 아니면 한국어 윈도우 인코딩으로 다시 시도
        return pd.read_csv(path, encoding="cp949", **kwargs)


files = sorted(glob.glob("data/raw/CARD_SUBWAY_MONTH_*.csv"))
print("파일 수:", len(files))

for f in files:
    name = os.path.basename(f)
    df = read_csv_auto(f).rename(columns=COLUMN_MAP)
    df["source_file"] = name  # 어느 파일에서 온 데이터인지 추적용

    # 파일 하나를 "지우고 다시 넣기"를 한 묶음(트랜잭션)으로 처리
    # → 중간에 실패해도 그 파일은 원래 상태로 돌아가고, 재실행해도 중복되지 않음
    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM raw.subway_ridership WHERE source_file = :f"),
            {"f": name},
        )
        df.to_sql(
            "subway_ridership", conn, schema="raw",
            if_exists="append", index=False, method="multi", chunksize=5000,
        )
    print(f"{name}: {len(df)}행 적재")


#적재결가화긴
with engine.connect() as conn:
    total = conn.execute(text("SELECT count(*) FROM raw.subway_ridership")).scalar()
print("raw 전체 행 수:", total)