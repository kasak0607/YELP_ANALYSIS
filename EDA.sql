CREATE OR REPLACE TABLE analytics_restaurant_monthly AS
SELECT
    business_id,
    TO_CHAR(DATE_TRUNC('month', review_date), 'YYYY-MM') AS year_month,
    COUNT(review_stars) AS reviews_count,
    ROUND(AVG(review_stars), 2) AS avg_rating,
    CASE 
        WHEN COUNT(review_stars) > 1 THEN ROUND(STDDEV(review_stars), 2)
        ELSE NULL
    END AS rating_volatility
FROM stg_yelp_reviews
GROUP BY business_id, year_month
ORDER BY business_id, year_month;

select * from  analytics_restaurant_monthly limit 10
-----------

CREATE OR REPLACE TABLE analytics_restaurant_checkins_monthly AS
SELECT
    business_id,
    TO_CHAR(DATE_TRUNC('month', date_visited), 'YYYY-MM') AS year_month,
    COUNT(*) AS checkins_count
FROM stg_tbl_checkins
WHERE business_id IS NOT NULL
GROUP BY business_id, year_month
ORDER BY business_id, year_month;

select * from  analytics_restaurant_checkins_monthly limit 1
select * from  stg_tbl_checkins limit 1
-------------------------------------------

CREATE OR REPLACE TABLE analytics_restaurant_rating_trend AS
SELECT
    business_id,
    year_month,
    avg_rating,
    LAG(avg_rating, 3) OVER (PARTITION BY business_id ORDER BY TO_DATE(year_month||'-01')) AS rating_3m_ago,
    ROUND(avg_rating - rating_3m_ago, 2) AS rating_change_3m
FROM analytics_restaurant_monthly
ORDER BY business_id, year_month;

-----------------
CREATE OR REPLACE TABLE analytics_restaurant_engagement AS
SELECT
    r.business_id,
    r.year_month,
    r.reviews_count,
    c.checkins_count,
    ROUND((r.reviews_count * 0.6) + (c.checkins_count * 0.4), 2) AS engagement_score
FROM analytics_restaurant_monthly r
JOIN analytics_restaurant_checkins_monthly c
  ON r.business_id = c.business_id
 AND r.year_month = c.year_month
ORDER BY r.business_id, r.year_month;

-----------------------------------
SELECT
    COUNT(*) AS missing_checkin_months
FROM analytics_restaurant_monthly r
LEFT JOIN analytics_restaurant_checkins_monthly c
  ON r.business_id = c.business_id
 AND r.year_month = c.year_month
WHERE c.year_month IS NULL;


SELECT CORR(r.reviews_count, t.rating_change_3m) AS review_vs_ratingDrop
FROM analytics_restaurant_monthly r
JOIN analytics_restaurant_rating_trend t
  ON r.business_id = t.business_id
 AND r.year_month = t.year_month;

