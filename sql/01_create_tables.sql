CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE IF NOT EXISTS raw.subway_ridership (
    use_date        TEXT,
    line_name       TEXT,
    station_name    TEXT,
    boarding_cnt    BIGINT,
    alighting_cnt   BIGINT,
    registered_date TEXT,
    source_file     TEXT,
    loaded_at       TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staging.subway_ridership (
    use_date        DATE    NOT NULL,
    line_name       TEXT    NOT NULL,
    station_name    TEXT    NOT NULL,
    boarding_cnt    INTEGER NOT NULL,
    alighting_cnt   INTEGER NOT NULL,
    registered_date DATE,
    PRIMARY KEY (use_date, line_name, station_name)
);