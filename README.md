# Yelp Behavioral Risk Analytics Report
#Business Objective

A closure-risk detection system was built using public Yelp interaction data. The goal was to prove whether customer engagement trends, review sentiment polarity, and rating stability signals can indicate business stress early and help predict which businesses may close, without revenue or internal finance data. The dataset contains many business types—restaurants, retail, nightlife, hotels, beauty, local services—so analysis is category-wide, not one vertical only.

#Summary

This analysis builds a predictive stress and closure risk framework using Yelp public behavioral signals ingested through Azure into Snowflake. The objective was to test whether early business stress and eventual closure can be predicted using interaction trends, sentiment polarity, rating movement, and stability signals, without internal financial data. The dataset contains businesses from many verticals: Restaurants, Retail, Beauty, Nightlife, Hotels, Local Services, Medical Stores, Automotive, Food Trucks, Home Services, and more. The architecture intentionally avoided filtering any vertical so that risk behavior could be compared across categories, like a real company-wide analytics initiative.

The final machine learning model validated risk separation on unseen test data with AUROC 0.70, meaning the model correctly ranks stressed or closure-risk businesses 70% of the time when compared to stable ones. Accuracy stabilized at 72–76% during validation runs. Precision and recall remained balanced, making the results reliable, realistic, and business-interpretable, not inflated or artificially perfect. Hypothesis tests returned p-value ≈ 0 for almost all cases due to dataset size, but the business effect size, lift behavior, trend patterns, and composite risk interpretation were the real drivers of conclusions.

#Data Source 

The primary dataset used in this project comes from the official Yelp Open Dataset published on the Yelp business data resources site. The data is publicly available for academic and commercial skill-building, and contains real user-generated interaction signals across millions of reviews and business profiles

https://business.yelp.com/data/resources/open-dataseta

The dataset is delivered in JSON format and includes multiple entity files. For this project, four core files were used as analytical sources:

Business profiles → structural metadata of Yelp-listed businesses

Reviews → user-written feedback and star ratings

Users → reviewer metadata including elite status and platform age

Check-ins → timestamp logs of visits to businesses

Each file was first uploaded into Azure storage and then referenced into Snowflake using an external stage. The data was copied into VARIANT tables to preserve JSON structure before flattening into analytical staging tables.

#Core Tables Created for Analysis

After loading raw JSON, structured analytical tables were built inside Snowflake SQL Notebook. Only essential fields were extracted, cast into clean types, deduplicated, null-handled, and then joined for modeling. The key analytical tables produced include:

STG_YELP_BUSINESS → BUSINESS_ID, NAME, CITY, STATE, STARS, REVIEW_COUNT, OPENED, CATEGORIES

STG_YELP_REVIEWS → BUSINESS_ID, REVIEW_ID, USER_ID, REVIEW_DATE, STARS, REVIEW_GIVEN, SENTIMENTS, FINAL_SENTIMENTS, SENTIMENT_SCORE

STG_YELP_USER → USER_ID, REVIEW_COUNT, ELITE, YELPING_SINCE, ELITE_REVIEWER_FLAG, USER_AGE_YEARS

STG_TBL_CHECKINS → BUSINESS_ID, DATE_VISITED

These four staging tables form the gold layer for behavioral trend analysis and risk modeling.

#Exploratory Data Analysis Observations

Because Yelp is public social data, it behaves chaotically, unlike internal company datasets. But chaos has patterns.

Key observations from EDA:

Most businesses receive fewer than 20 reviews a month, while a small minority dominate engagement, crossing 1000+ monthly reviews. This is normal social inequality distribution, not an error. Check-in logs have missing months for some businesses, meaning foot traffic is incomplete. So check-ins must be interpreted as trend proxies for interest, not absolute visit truth. Rating volatility spikes mostly when monthly review volume is low. So volatility is a stress indicator only when >1 review exists, otherwise it is noise. Sentiment polarity distribution is heavily positive in most months. This reflects a human positivity bias in public platforms. But negative sentiment ratios spike sharply in stress months before closure. Very popular businesses do not stay open more or less by default. But popularity momentum decline over time amplifies stress detection measurably. Category tags overlap strongly. Most businesses carry 2–4 vertical tags like "Food, Nightlife, Retail, Restaurants". So modeling must remain category-wide. Filtering to restaurants alone would destroy insight intelligence.
