CREATE OR REPLACE TABLE yelp_reviews (
    review_text VARIANT
);

-- Create a storage integration object
CREATE STORAGE INTEGRATION snowflake_azure_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = AZURE
  ENABLED = TRUE
  AZURE_TENANT_ID = 'bad12864-913e-4b99-87d6-b8d2ad459e27'
  STORAGE_ALLOWED_LOCATIONS = (
    'azure://yelpanalyticsdl.blob.core.windows.net/yelp-raw'
  );


DESC INTEGRATION snowflake_azure_integration;

CREATE OR REPLACE FILE FORMAT yelp_json_ff
  TYPE = JSON;
CREATE OR REPLACE STAGE yelp_stage
  URL = 'azure://yelpanalyticsdl.blob.core.windows.net/yelp-raw'
  STORAGE_INTEGRATION = snowflake_azure_integration
  FILE_FORMAT = yelp_json_ff;

LIST @yelp_stage;
COPY INTO yelp_reviews
FROM @yelp_stage
FILE_FORMAT = (TYPE = JSON);

SELECT * FROM yelp_reviews limit 100 ;
CREATE OR REPLACE TABLE yelp_business (
    business_text VARIANT
);

CREATE OR REPLACE FILE FORMAT yelp_business_ff
  TYPE = JSON;
  
COPY INTO yelp_business
FROM @yelp_stage/yelp_academic_dataset_business.json
FILE_FORMAT = yelp_business_ff;
SELECT count(*) FROM yelp_business;

select * from yelp_business limit 100

create or replace table tbl_yelp_reviews as
SELECT
    review_text:business_id::STRING AS business_id,
    review_text:date::DATE AS review_date,
    review_text:user_id::string as user_id,
    review_text:review_id::string as review_id,

    review_text:stars::NUMBER AS review_stars,
    review_text:text::STRING AS review_given,
    analyze_sentiment(review_given) as sentiments,
      case
        when review_stars >= 4 and analyze_sentiment(review_given) = 'Positive' then 'Strong Positive'
        when review_stars >= 4 and analyze_sentiment(review_given) = 'Negative' then 'Mismatch Risk'
        when review_stars <= 2 and analyze_sentiment(review_given) = 'Negative' then 'Strong Negative'
        when review_stars <= 2 and analyze_sentiment(review_given) = 'Positive' then 'Anomaly'
        else 'Neutral'
    end as final_sentiment
FROM yelp_reviews limit 10;
select * from tbl_yelp_reviews limit 1000
select final_sentiment,count('Highly Positive')
--,count('Mismatch Risk'),count('Strong Negative'),count('Anomaly'),count('Neutral') 
from tbl_yelp_reviews
group by final_sentiment

create or replace table tbl_yelp_business as
SELECT
    business_text:business_id::STRING AS business_id,
business_text:name::STRING AS name,

business_text:city::STRING AS city,
    business_text:state::STRING AS state,
    business_text:review_count::NUMBER AS review_count,
    business_text:stars::NUMBER AS stars,
    business_text:categories::STRING AS categories,
    business_text:is_open::NUMBER AS opened

FROM yelp_business
LIMIT 100;
select * from tbl_yelp_business

--------------

CREATE OR REPLACE TABLE yelp_user (
    users_text VARIANT
);

CREATE OR REPLACE FILE FORMAT yelp_user_ff
  TYPE = JSON;
  
COPY INTO yelp_user
FROM @yelp_stage/yelp_academic_dataset_user.json
FILE_FORMAT = yelp_user_ff;
select * from yelp_user limit 100

create or replace table tbl_yelp_user as
SELECT
    users_text:user_id::STRING AS user_id,
    users_text:review_count::NUMBER AS review_count,
    users_text:elite::STRING AS elite,
    users_text:yelping_since::TIMESTAMP_NTZ AS yelping_since
FROM yelp_user
limit 100
-------------------------------
CREATE OR REPLACE TABLE yelp_checkin (
    checkin_text VARIANT
);

CREATE OR REPLACE FILE FORMAT yelp_checkin_ff
  TYPE = JSON;
  
COPY INTO yelp_checkin
FROM @yelp_stage/yelp_academic_dataset_checkin.json
FILE_FORMAT = yelp_checkin_ff;
select * from yelp_checkin 

CREATE OR REPLACE TABLE tbl_checkins AS
SELECT
    checkin_text:business_id::STRING AS business_id,
    TRIM(value)::TIMESTAMP_NTZ AS date_visited
FROM yelp_checkin,
     LATERAL SPLIT_TO_TABLE(checkin_text:date::STRING, ',');
select * from tbl_checkins limit 100
