--Can We Predict Restaurant Failure Risk and Revenue Stress Using Public Behavioral Signals Alone?--
--EDA 
--Count check
SELECT COUNT(*) FROM tbl_yelp_reviews;
-- NULL Value check
SELECT
    COUNT(*) AS total_rows,

    -- STRING columns
    COUNT_IF(business_id IS NULL OR TRIM(business_id) = '') AS business_id_missing,
    COUNT_IF(review_id IS NULL OR TRIM(review_id) = '') AS review_id_missing,
    COUNT_IF(user_id IS NULL OR TRIM(user_id) = '') AS user_id_missing,
    COUNT_IF(review_given IS NULL OR TRIM(review_given) = '') AS review_text_missing,
    COUNT_IF(sentiments IS NULL OR TRIM(sentiments) = '') AS sentiment_missing,
    COUNT_IF(final_sentiment IS NULL OR TRIM(final_sentiment) = '') AS final_sentiment_missing,

    -- NON-STRING columns
    COUNT_IF(review_date IS NULL) AS review_date_missing,
    COUNT_IF(review_stars IS NULL) AS review_stars_missing

FROM tbl_yelp_reviews;


-- No NULL
-- Star rating sanity
SELECT review_stars, COUNT(*)
FROM tbl_yelp_reviews
GROUP BY review_stars
ORDER BY review_stars;
-- No ambiguity

--DUPLICATE CHECK
SELECT
    business_id,
    review_date,
    review_given,
    COUNT(*) AS cnt
FROM tbl_yelp_reviews
GROUP BY business_id, review_date, review_given
HAVING COUNT(*) > 1;
-- Duplicate exits

--soln--

CREATE OR REPLACE TABLE stg_yelp_reviews AS
SELECT *
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY review_id ORDER BY review_date) AS rn
    FROM tbl_yelp_reviews
)
WHERE rn = 1;

ALTER TABLE stg_yelp_reviews
DROP COLUMN rn;

UPDATE stg_yelp_reviews
SET review_date = DATE(review_date);

DESCRIBE TABLE stg_yelp_reviews;


SELECT BUSINESS_ID,TO_CHAR(review_date, 'Mon') AS month_name,YEAR(review_date),COUNT(*) AS reviews
FROM STG_YELP_REVIEWS
GROUP BY 1,2,3
 having reviews>10
 ORDER BY 3,2;

 create or replace table STG_YELP_REVIEWS as
 select *,TO_CHAR(review_date, 'Mon') AS month_name,YEAR(review_date) as year_name
 from STG_YELP_REVIEWS 

SELECT BUSINESS_ID,YEAR(review_date),COUNT(*) AS reviews
FROM STG_YELP_REVIEWS
GROUP BY 1,2
 having reviews>10
 ORDER BY 2;

WITH yearly_counts AS (
  SELECT
      business_id,
      YEAR(review_date) AS yr,
      COUNT(*) AS review_cnt
  FROM stg_yelp_reviews
  GROUP BY business_id, yr
  HAVING review_cnt > 10
)
SELECT
    business_id,
    COUNT(DISTINCT yr) AS years_with_10plus_reviews
FROM yearly_counts
GROUP BY business_id
ORDER BY years_with_10plus_reviews DESC;

SELECT
        business_id,COUNT(*) AS total_reviews,
FROM stg_yelp_reviews
GROUP BY business_id
ORDER BY total_reviews DESC
LIMIT 20;

SELECT
    business_id,
    AVG(review_stars) AS avg_rating,
    STDDEV(review_stars) AS rating_volatility,
    COUNT(*) AS review_count
FROM stg_yelp_reviews
GROUP BY business_id
HAVING COUNT(*) > 20
ORDER BY rating_volatility DESC;

select distinct year_name from stg_yelp_reviews
select SENTIMENT_SCORE from stg_yelp_reviews
UPDATE stg_yelp_reviews
SET SENTIMENT_SCORE = sentiment(REVIEW_GIVEN);


-------------
--YELP_BUSINESS
SELECT COUNT(*) FROM tbl_yelp_business;

SELECT business_id, COUNT(*)
FROM tbl_yelp_business
GROUP BY business_id
HAVING COUNT(*) > 1; -- No duplicate

SELECT opened, COUNT(*)
FROM tbl_yelp_business
GROUP BY opened; -- No ambiguity

SELECT categories, COUNT(*)
FROM tbl_yelp_business
GROUP BY categories
ORDER BY COUNT(*) DESC---cetegory count

with cte as(select 
business_id, 
trim(A.value) as cetegory
from tbl_yelp_business
,lateral split_to_table(categories,',') 
A
)
select cetegory,count(*) as no_of_business from cte group by 1
order by count(*) desc -- pivoting

SELECT
    COUNT(*) AS total_rows,

    -- STRING columns
    COUNT_IF(business_id IS NULL OR TRIM(business_id) = '') AS business_id_missing,
    COUNT_IF(name IS NULL OR TRIM(name) = '') AS name_missing,
    COUNT_IF(city IS NULL OR TRIM(city) = '') AS city_missing,
    COUNT_IF(state IS NULL OR TRIM(state) = '') AS state_missing,
    COUNT_IF(categories IS NULL OR TRIM(categories) = '') AS categories_missing,

    -- NUMBER columns
    COUNT_IF(review_count IS NULL) AS review_count_missing,
    COUNT_IF(stars IS NULL) AS stars_missing,
    COUNT_IF(opened IS NULL) AS is_open_missing

FROM tbl_yelp_business; --103 cetegories missing

SELECT *
FROM tbl_yelp_business
WHERE business_id IS NULL
   OR name IS NULL
   OR city IS NULL
   OR state IS NULL
   OR stars IS NULL
   OR review_count IS NULL
   OR opened IS NULL
   OR categories IS NULL;

--null handling 

   CREATE OR REPLACE TABLE stg_yelp_business AS
SELECT
    business_id,
    name,
    city,
    state,
    stars,
    review_count,
    opened,
    COALESCE(NULLIF(TRIM(categories), ''), 'Unknown') AS categories
FROM tbl_yelp_business;

UPDATE stg_yelp_business
SET categories = TRIM(categories);

select * from stg_yelp_business

---------------

SELECT COUNT(*) FROM tbl_checkins;
SELECT
  COUNT(*) AS total_rows,
  COUNT_IF(user_id IS NULL OR TRIM(user_id)='') AS user_id_missing,
  COUNT_IF(review_count IS NULL) AS review_count_missing,
  COUNT_IF(elite IS NULL OR TRIM(elite)='') AS elite_missing,
  COUNT_IF(yelping_since IS NULL) AS yelping_since_missing
FROM tbl_yelp_user; -1896699/1987897 elite_missing 

SELECT *
FROM tbl_yelp_user
WHERE elite IS NULL 
   OR TRIM(elite) != '';


SELECT
    MIN(date_visited) AS first_checkin,
    MAX(date_visited) AS last_checkin
FROM tbl_checkins;

--------------------------

SELECT COUNT(*) FROM tbl_yelp_user;

SELECT
    COUNT(*) AS total,
    COUNT(elite) AS elite_count,
    COUNT_IF(elite IS NULL) AS elite_nulls,
    COUNT_IF(elite = '') AS elite_empty_strings
FROM tbl_yelp_user;

CREATE OR REPLACE TABLE stg_yelp_user AS
SELECT
    users_text:user_id::STRING AS user_id,
    users_text:review_count::NUMBER AS review_count,
    CASE 
        WHEN TRIM(users_text:elite::STRING) = '' THEN 'NOT ELITE'
        ELSE users_text:elite::STRING
    END AS elite,
    users_text:yelping_since::TIMESTAMP_NTZ AS yelping_since
FROM yelp_user;

select COUNT(*) from  stg_yelp_user where elite='NOT ELITE'

SELECT business_id, date_visited, COUNT(*) AS c
FROM tbl_checkins
GROUP BY business_id, date_visited
HAVING c > 1;

CREATE OR REPLACE TABLE stg_tbl_checkins AS
SELECT *
FROM (
    SELECT 
        business_id,
        date_visited,
        ROW_NUMBER() OVER (PARTITION BY business_id, date_visited ORDER BY date_visited DESC) AS rn
    FROM tbl_checkins
) t
WHERE rn = 1;
select * from stg_tbl_checkins limit 10

