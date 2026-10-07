-- 분석 1) 월별 승차 인원 상위 5개 역 (RANK: 월마다 따로 순위를 매김)
SELECT *
FROM (
    SELECT
        dd.month,
        s.line_name,
        s.station_name,
        sum(f.boarding_cnt) AS boarding_sum,
        RANK() OVER (
            PARTITION BY dd.month               -- 월별로 나눠서
            ORDER BY sum(f.boarding_cnt) DESC   -- 승차 합계가 큰 순서로 순위
        ) AS rnk
    FROM mart.fact_ridership AS f
    JOIN mart.dim_station AS s USING (station_id)
    JOIN mart.dim_date AS dd ON dd.date_id = f.date_id
    GROUP BY dd.month, s.line_name, s.station_name
) AS t
WHERE rnk <= 5
ORDER BY month, rnk;


-- 분석 2) 1~9호선 월별 "하루 평균 승차 인원"과 전월 대비 증감률
-- 월 합계 대신 일평균을 쓰는 이유: 31일 달과 30일 달을 공평하게 비교하려고
WITH line_month AS (
    SELECT
        s.line_name,
        dd.month,
        round(sum(f.boarding_cnt)::numeric / count(DISTINCT f.date_id)) AS daily_avg
    FROM mart.fact_ridership AS f
    JOIN mart.dim_station AS s USING (station_id)
    JOIN mart.dim_date AS dd ON dd.date_id = f.date_id
    WHERE s.line_name IN ('1호선','2호선','3호선','4호선','5호선','6호선','7호선','8호선','9호선')
    GROUP BY s.line_name, dd.month
),
with_prev AS (
    SELECT
        line_name,
        month,
        daily_avg,
        LAG(daily_avg) OVER (PARTITION BY line_name ORDER BY month) AS prev_avg  -- 직전 달 값
    FROM line_month
)
SELECT
    line_name,
    month,
    daily_avg,
    prev_avg,
    round(100.0 * (daily_avg - prev_avg) / NULLIF(prev_avg, 0), 1) AS mom_pct  -- 첫 달은 NULL
FROM with_prev
ORDER BY line_name, month;


-- 분석 3) 1~9호선 평일 vs 주말 하루 평균 승차 인원
WITH daily AS (
    -- 노선별 하루 승차 합계를 먼저 만든다
    SELECT
        f.date_id,
        s.line_name,
        sum(f.boarding_cnt) AS day_sum
    FROM mart.fact_ridership AS f
    JOIN mart.dim_station AS s USING (station_id)
    WHERE s.line_name IN ('1호선','2호선','3호선','4호선','5호선','6호선','7호선','8호선','9호선')
    GROUP BY f.date_id, s.line_name
)
SELECT
    d.line_name,
    round(avg(d.day_sum) FILTER (WHERE NOT dd.is_weekend)) AS weekday_avg,
    round(avg(d.day_sum) FILTER (WHERE dd.is_weekend))     AS weekend_avg,
    -- 주말이 평일의 몇 %인지 (100보다 작으면 주말에 이용이 줄어듦)
    round(
        100.0 * avg(d.day_sum) FILTER (WHERE dd.is_weekend)
        / NULLIF(avg(d.day_sum) FILTER (WHERE NOT dd.is_weekend), 0),
        1
    ) AS weekend_pct_of_weekday
FROM daily AS d
JOIN mart.dim_date AS dd ON dd.date_id = d.date_id
GROUP BY d.line_name
ORDER BY d.line_name;