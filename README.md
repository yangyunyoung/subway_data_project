서울 지하철 승하차 데이터 파이프라인

서울시 지하철 호선별·역별 일일 승하차 인원 CSV(6개월, 113,564행)를 PostgreSQL에 적재하고, 3계층(raw → staging → mart)으로 정리한 뒤 SQL로 분석한 데이터 엔지니어링 토이프로젝트입니다.

프로젝트 목표
원본 CSV의 문제를 발견하고 정제해서 DB에 안전하게 적재하기
재실행해도 데이터가 중복되지 않는 적재 구조(멱등성) 만들기
분석에 쓰기 좋은 스타 스키마(dim/fact)를 설계하고 SQL로 질문에 답하기
airflow 활용


데이터
항목	내용
출처	서울 열린데이터광장, 「서울시 지하철호선별 역별 승하차 인원 정보」 (제공: 서울특별시)
컬럼	사용일자, 노선명, 역명, 승차총승객수, 하차총승객수, 등록일자
유의점	교통카드 기반 집계이며 환승객 여부와 상관없이 집계된 수치

원본 CSV는 저장소에 포함하지 않았습니다. 이용 조건은 해당 데이터셋 상세 페이지를 따릅니다.

기술 스택

Python (Pandas, SQLAlchemy, psycopg2), PostgreSQL 13, Docker

아키텍처
load_raw.py
02_load_staging.sql
05_load_mart.sql
07_analysis.sql
월별 CSV 6개
raw원본 그대로
staging타입·공백 정리
mart분석용 스타 스키마
분석 결과
계층	테이블	역할
raw	raw.subway_ridership	CSV를 가공 없이 보관 (출처 파일명, 적재 시각 포함)
staging	staging.subway_ridership	날짜를 DATE로, 인원을 정수로 변환. 키: (use_date, line_name, station_name)
mart	dim_station, dim_date, fact_ridership	분석용. 역은 노선+역 조합이 한 행
station_id
date_id
DIM_STATION
int
station_id
PK
text
line_name
text
station_name
FACT_RIDERSHIP
date
date_id
PK,FK
int
station_id
PK,FK
int
boarding_cnt
int
alighting_cnt
DIM_DATE
date
date_id
PK
int
year
int
month
int
day
int
weekday_num
boolean
is_weekend
폴더 구조
subway_data_project/
├── README.md
├── .gitignore
├── data/raw/            # 원본 CSV (git 제외)
├── src/
│   ├── explore.py       # 데이터 탐색 (행 수, 타입, 결측, 키 중복)
│   ├── peek.py          # 원본 CSV 앞 줄을 그대로 출력 (컬럼 밀림 확인용)
│   └── load_raw.py      # CSV → raw 적재
├── sql/
│   ├── 01_create_tables.sql   # 스키마, raw/staging 테이블
│   ├── 02_load_staging.sql    # raw → staging
│   ├── 03_checks.sql          # staging 검증
│   ├── 04_create_mart.sql     # mart 테이블
│   ├── 05_load_mart.sql       # staging → mart
│   ├── 06_checks_mart.sql     # mart 검증
│   └── 07_analysis.sql        # 분석 쿼리 3개
└── docs/result.txt      # 분석 쿼리 실행 결과
실행 방법

1. 준비

bash
git clone https://github.com/yangyunyoung/subway_data_project.git
cd subway_data_project
pip install pandas sqlalchemy psycopg2-binary

서울 열린데이터광장에서 월별 CSV를 받아 data/raw/에 CARD_SUBWAY_MONTH_YYYYMM.csv 형태로 둡니다.

2. PostgreSQL 실행 (예시, 로컬 5433 포트)

bash
docker run --name subway-postgres -e POSTGRES_USER=airflow -e POSTGRES_PASSWORD=airflow \
  -e POSTGRES_DB=subway_db -p 127.0.0.1:5433:5432 -d postgres:13

3. 테이블 생성 → 적재 → 분석 (Windows cmd / bash 기준)

bash
docker exec -i subway-postgres psql -U airflow -d subway_db < sql/01_create_tables.sql
python src/load_raw.py
docker exec -i subway-postgres psql -U airflow -d subway_db < sql/02_load_staging.sql
docker exec -i subway-postgres psql -U airflow -d subway_db < sql/04_create_mart.sql
docker exec -i subway-postgres psql -U airflow -d subway_db < sql/05_load_mart.sql
docker exec -i subway-postgres psql -U airflow -d subway_db < sql/07_analysis.sql

PowerShell에서는 <가 동작하지 않으므로 Get-Content sql\파일명.sql -Raw | docker exec -i ... 형태로 실행합니다. 접속 정보는 환경변수(DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME)로 바꿀 수 있습니다.

결과 요약

파이프라인

월별 CSV 6개 113,564행을 raw → staging → mart로 적재 (날짜 184일, 노선+역 626개)
raw 적재 스크립트를 2회 연속 실행해도 행 수 113,564건 유지 (파일 단위 delete-insert를 하나의 트랜잭션으로 처리)
staging·mart는 ON CONFLICT(upsert)로 같은 키가 중복 적재되지 않도록 설계

분석에서 확인한 것

월별 승차 상위 역: 1~4위는 6개월 내내 잠실(송파구청)·강남·서울역·홍대입구이고 순서만 달라집니다. 5위는 3~4월 구로디지털단지, 5~8월 성수입니다.
1~9호선 일평균 승차의 전월 대비 증감: 4월은 전 호선 증가(+3.5% ~ +7.3%), 5월은 전 호선 감소(-3.0% ~ -9.6%), 7·8월은 전 호선 연속 감소입니다.
주말 일평균이 평일의 몇 %인지
호선	평일 일평균	주말 일평균	주말/평일
1호선	292,800	224,082	76.5%
2호선	1,571,611	1,059,128	67.4%
3호선	594,112	405,767	68.3%
4호선	583,832	426,595	73.1%
5호선	752,788	472,126	62.7%
6호선	377,675	263,439	69.8%
7호선	667,983	402,464	60.3%
8호선	235,073	147,469	62.7%
9호선	327,488	198,165	60.5%

전체 결과는 docs/result.txt에 있습니다.

겪은 문제와 해결

1. CSV 컬럼이 한 칸씩 밀려서 읽힘

증상: head()에서 사용일자 칸에 5호선이 들어가고, 역명 타입이 숫자, 등록일자가 전부 결측으로 나옴
원인: 제목 줄은 6칸인데 데이터 줄은 끝에 빈 칸이 하나 더 있어 7칸이었음. pandas가 맨 앞 칸(날짜)을 인덱스로 처리해 날짜가 사라지고 나머지가 밀림
해결: peek.py로 원본 줄을 그대로 출력해 확인한 뒤 index_col=False로 읽고, 날짜는 문자열로 읽도록 지정
검증: 행 수 113,564 유지, 날짜 범위 2026-03-01 ~ 2026-08-31, 등록일자 결측 0

2. 역 이름만으로는 역을 구분할 수 없음

환승역은 노선마다 따로 행으로 존재 (역 이름 기준 533개, 노선+역 기준 626개)
그래서 (사용일자, 노선명, 역명)을 staging의 키로, (노선명, 역명)을 dim_station의 기준으로 설계 (6개월치에서 키 중복 0 확인)

3. 월 합계로 비교하면 일수 차이가 반영됨

31일 달과 30일 달의 합계를 비교하면 증감률이 왜곡되므로, 전월 대비 분석은 일평균으로 계산
한계와 향후 계획
환승객 구분 없이 집계된 수치이며, 기간이 6개월이라 계절 전체를 대표하지는 않습니다.
is_weekend는 토·일만 주말로 보고 공휴일은 평일로 계산합니다. 공휴일 데이터를 붙이면 주말 비교가 더 정확해집니다.
분석 결과의 원인(날씨, 휴가철 등)은 이 데이터만으로 단정할 수 없습니다.
향후: 적재 단계를 한 번에 실행하는 스크립트, Airflow DAG로 월별 자동 적재, 공휴일 데이터 반영
