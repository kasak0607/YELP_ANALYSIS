# Yelp Behavioral Risk Analytics Report
# Business Objective

The business question tackled was:

**Can public Yelp behavioral signals detect business stress early and separate closure-risk businesses before shutdown windows appear, without revenue or internal finance data?**

In real life, business closure is not a single event, it is a stress evolution process, where behavioral signals collapse, spike, or destabilize before a business goes offline permanently.
Business failure was defined not by a single month open/close flag, but by long-term closure density, engineered later into FAILED_FLAG. This prevents the system from mislabeling temporary low engagement months, seasonality effects, or Yelp logging gaps as business death.
A business is realistically considered failed/stressed only when:

- It was ever open (IS_OPEN = 1)

- It later showed long closure months (IS_OPEN = 0)

- It remained closed for 6+ months or more

- It shows stress behavior in the 3-month window before closure density spikes

This definition is important because Yelp has no revenue field, no failure tag, and check-in logs are incomplete in some months. So stress detection had to rely on behavioral momentum, sentiment density, and stability loss, not internal financial truth.

#Data Source 

The primary dataset used in this project comes from the official Yelp Open Dataset published on the Yelp business data resources site. The data is publicly available for academic and commercial skill-building, and contains real user-generated interaction signals across millions of reviews and business profiles

https://business.yelp.com/data/resources/open-dataseta

The dataset is delivered in JSON format and includes multiple entity files. For this project, four core files were used as analytical sources:

Business profiles(150,346 rows) → structural metadata of Yelp-listed businesses

Reviews(6,990,280 rows) → user-written feedback and star ratings

Users(1,987,897 rows) → reviewer metadata including elite status and platform age

Check-ins(131,930rows) → timestamp logs of visits to businesses

Each file was first uploaded into Azure storage and then referenced into Snowflake using an external stage. The data was copied into VARIANT tables to preserve JSON structure before flattening into analytical staging tables.

#Core Tables Created for Analysis

After loading raw JSON, structured analytical tables were built inside Snowflake SQL Notebook. Only essential fields were extracted, cast into clean types, deduplicated, null-handled, and then joined for modeling. The key analytical tables produced include:

STG_YELP_BUSINESS → BUSINESS_ID, NAME, CITY, STATE, STARS, REVIEW_COUNT, OPENED, CATEGORIES

STG_YELP_REVIEWS → BUSINESS_ID, REVIEW_ID, USER_ID, REVIEW_DATE, STARS, REVIEW_GIVEN, SENTIMENTS, FINAL_SENTIMENTS, SENTIMENT_SCORE

STG_YELP_USER → USER_ID, REVIEW_COUNT, ELITE, YELPING_SINCE, ELITE_REVIEWER_FLAG, USER_AGE_YEARS

STG_TBL_CHECKINS → BUSINESS_ID, DATE_VISITED

These four staging tables form the gold layer for behavioral trend analysis and risk modeling.



# Exploratory Data Analysis Observations
- Review count distribution is extremely skewed → few businesses have very high reviews, most have low-medium reviews. This means popularity must be treated carefully, or models will bias toward famous businesses only.

- Check-in count distribution is also skewed → many businesses have very low visits logged, some have massive foot-traffic months. This is expected because Yelp engagement depends on customer habit, not business size.

- Rating volatility is higher when review volume is low. If 1 business gets only 2 reviews in a month, and one is 5★ and other is 1★, volatility becomes huge. This makes volatility a stress indicator only when enough reviews exist, not when data is small.

- Sentiment ratio shows negativity is present but rarely dominant. Most Yelp users lean positive or neutral, so negative sentiment alone won’t predict closure, but negative ratio + engagement drop + volatility combined show stress reliably.
- Correlation Behavior Interpretation

The correlations that mattered most were:

- Engagement velocity vs rating slope decline

- Negative sentiment ratio vs volatility spikes

- Momentum collapse months vs future closure density

These are trend-interaction correlations, not static ones.

Interpretation :

Yelp risk signals behave non-linearly. Social behavioral data will rarely show strong Pearson correlation with a binary closure flag. The correct analytical interpretation is to engineer lag-based trend deltas and test group lift behavior

# Hypothesis Testing 
Five core behavioral hypotheses were tested, each designed to reflect real business stress signatures, not academic theory only.

- **Hypothesis 1: Engagement collapse months are followed by lower ratings later
**
This hypothesis tested whether businesses that drop below median engagement scores show lower ratings in future months. The result returned p-value ≈ 0, meaning the stressed group and stable group were statistically different. But the real interpretation is in trend behavior, not the p-value.

Businesses in the ENGAGEMENT_DROP group showed:

- Higher negative sentiment density in those months

- Measurable rating decline in the next 3 months

- Stronger stress concentration across all verticals, not only restaurants

- Engagement drop was not a rare anomaly — it appeared consistently before closure density windows

This validates a temporal cause-effect signature:

- Customer interest ↓ → review momentum ↓ → satisfaction ↓ months later → stress signature ↑

This is not linear correlation, but time-lag behavior stress linkage

**- Hypothesis 2: 3-month rating decline is linked with engagement deceleration
**
This hypothesis compared LAG(AVG_RATING,3) slope changes against engagement movement. Again, p ≈ 0, but more importantly:

- Months where rating slope declined more than 0.4 stars over 3 months also showed review + check-in momentum collapse

- Engagement velocity drop and rating slope decline were paired signatures, not separate behaviors

This proves:

- Satisfaction slope ↓ → engagement momentum ↓ → stress risk signal ↑

- Interpretation:

- Customers lose interest when ratings fall

- Rating stress is not emotional noise only, it comes with measurable momentum decline

The model later confirmed the same pattern using AUROC ranking ability.

- **Hypothesis 3: Businesses with unstable ratings have slightly higher closure density
**
The segmentation results showed:

- 19.57% of HIGH_VOLATILITY businesses were closed

- 16.92% of LOW_VOLATILITY businesses were closed

- Absolute lift only ≈ 2.65%

- Interpretation:

- Volatility alone is weak. But volatility is a stress amplifier when combined with sentiment or momentum collapse.
- So the conclusion becomes conditional: Volatility is useful only when other stress signals collapse or spike together

**- Hypothesis 4: Popular businesses do not close less or more by default
**
H4 p VALUE = 2.3 × 10⁻²⁶⁶
That is extremely significant mathematically. But the segmentation table shows:

- All popularity tiers had ~79–80% OPENED percentage

- Closure % was nearly equal across all groups

- Interpretation:

- Static popularity does not change closure probability

- Popularity momentum decline over time is what matters, not static tiers

-We learned that popularity as a trend signal, not a standalone closure protector

**- Hypothesis 5: Elite reviewers influence stressed months more strongly, but don’t predict closure alone
**
- H5 p value: 0
- Interpretation:

  Elite reviewers mostly belong to older Yelp accounts and influence rating momentum direction in stressed months but elite reviewer flag does not shift closure risk alone

- Conclusion:

Reviewer trust amplifies stress severity, but does not cause closure alone



