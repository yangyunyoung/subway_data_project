SELECT 'raw' AS layer, count(*) AS row_cnt FROM raw.subway_ridership
UNION ALL
SELECT 'staging', count(*) FROM staging.subway_ridership;

SELECT min(use_date) AS first_day,
       max(use_date) AS last_day,
       count(DISTINCT use_date) AS days
FROM staging.subway_ridership;

SELECT count(*) AS negative_rows
FROM staging.subway_ridership
WHERE boarding_cnt < 0 OR alighting_cnt < 0;