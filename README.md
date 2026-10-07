서울 지하철 승하차 데이터 파이프라인

서울시 지하철 호선별·역별 일일 승하차 인원 CSV(6개월, 113,564행)를 PostgreSQL에 적재하고, 3계층(raw → staging → mart)으로 정리한 뒤 SQL로 분석한 데이터 엔지니어링 토이프로젝트입니다.

[프로젝트 목표]
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

- 월별 CSV 6개 113,564행을 raw → staging → mart로 적재 (날짜 184일, 노선+역 626개)
- raw 적재 스크립트를 2회 연속 실행해도 행 수 113,564건 유지 (파일 단위 delete-insert를 하나의 트랜잭션으로 처리)
- staging·mart는 ON CONFLICT(upsert)로 같은 키가 중복 적재되지 않도록 설계

분석에서 확인한 것

1. 월별 승차 상위 역: 1~4위는 6개월 내내 잠실(송파구청)·강남·서울역·홍대입구이고 순서만 달라집니다. 5위는 3~4월 구로디지털단지, 5~8월 성수입니다.
2. 1~9호선 일평균 승차의 전월 대비 증감: 4월은 전 호선 증가(+3.5% ~ +7.3%), 5월은 전 호선 감소(-3.0% ~ -9.6%), 7·8월은 전 호선 연속 감소입니다.
3. 주말 일평균이 평일의 몇 %인지

전체 결과는 docs/result.txt에 있습니다.

