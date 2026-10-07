-- 1) 역 목록: staging에 나온 (노선, 역) 조합을 모아서 넣는다 (이미 있으면 건너뜀)
INSERT INTO mart.dim_station (line_name, station_name)
SELECT DISTINCT line_name, station_name
FROM staging.subway_ridership
ON CONFLICT (line_name, station_name) DO NOTHING;

-- 2) 날짜 목록: 날짜에서 연·월·일·요일을 뽑아서 넣는다
INSERT INTO mart.dim_date (date_id, year, month, day, weekday_num, is_weekend)
SELECT DISTINCT
    use_date,
    EXTRACT(YEAR  FROM use_date)::integer,
    EXTRACT(MONTH FROM use_date)::integer,
    EXTRACT(DAY   FROM use_date)::integer,
    EXTRACT(ISODOW FROM use_date)::integer,
    EXTRACT(ISODOW FROM use_date) IN (6, 7)
FROM staging.subway_ridership
ON CONFLICT (date_id) DO NOTHING;

-- 3) 사실 테이블: 역 이름 대신 station_id를 붙여서 넣는다
--    같은 (날짜, 역)이 이미 있으면 인원 수만 갱신 (재실행해도 중복 없음)
INSERT INTO mart.fact_ridership (date_id, station_id, boarding_cnt, alighting_cnt)
SELECT
    s.use_date,
    d.station_id,
    s.boarding_cnt,
    s.alighting_cnt
FROM staging.subway_ridership AS s
JOIN mart.dim_station AS d
    ON d.line_name = s.line_name
   AND d.station_name = s.station_name
ON CONFLICT (date_id, station_id)
DO UPDATE SET
    boarding_cnt  = EXCLUDED.boarding_cnt,
    alighting_cnt = EXCLUDED.alighting_cnt;