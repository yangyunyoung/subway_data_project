INSERT INTO staging.subway_ridership
    (use_date, line_name, station_name, boarding_cnt, alighting_cnt, registered_date)
SELECT
    to_date(use_date, 'YYYYMMDD'),
    trim(line_name),
    trim(station_name),
    boarding_cnt::integer,
    alighting_cnt::integer,
    to_date(NULLIF(registered_date, ''), 'YYYYMMDD')
FROM raw.subway_ridership
ON CONFLICT (use_date, line_name, station_name)
DO UPDATE SET
    boarding_cnt    = EXCLUDED.boarding_cnt,
    alighting_cnt   = EXCLUDED.alighting_cnt,
    registered_date = EXCLUDED.registered_date;