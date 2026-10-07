-- 역 차원: "노선 + 역 이름" 조합이 한 행 (환승역은 노선마다 따로 있음)
CREATE TABLE IF NOT EXISTS mart.dim_station (
    station_id   SERIAL PRIMARY KEY,
    line_name    TEXT NOT NULL,
    station_name TEXT NOT NULL,
    UNIQUE (line_name, station_name)
);

-- 날짜 차원: 요일·주말 분석을 쉽게 하려고 날짜를 쪼개서 보관
CREATE TABLE IF NOT EXISTS mart.dim_date (
    date_id     DATE PRIMARY KEY,
    year        INTEGER NOT NULL,
    month       INTEGER NOT NULL,
    day         INTEGER NOT NULL,
    weekday_num INTEGER NOT NULL,  -- 1=월 ... 7=일
    is_weekend  BOOLEAN NOT NULL   -- 토·일만 true (공휴일은 반영하지 않음)
);

-- 사실 테이블: 하루 × 역별 승차/하차 인원
CREATE TABLE IF NOT EXISTS mart.fact_ridership (
    date_id       DATE    NOT NULL REFERENCES mart.dim_date (date_id),
    station_id    INTEGER NOT NULL REFERENCES mart.dim_station (station_id),
    boarding_cnt  INTEGER NOT NULL,
    alighting_cnt INTEGER NOT NULL,
    PRIMARY KEY (date_id, station_id)
);