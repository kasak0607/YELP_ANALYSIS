# Yelp Behavioral Risk Analytics Report

**1. Business Objective**

- The business question tackled was:

**Can public Yelp behavioral signals detect business stress early and separate closure-risk businesses before shutdown windows appear, without revenue or internal finance data?**

- In real life, business closure is not a single event, it is a stress evolution process, where behavioral signals collapse, spike, or destabilize before a business goes offline permanently.
Business failure was defined not by a single month open/close flag, but by long-term closure density, engineered later into FAILED_FLAG. This prevents the system from mislabeling temporary low engagement months, seasonality effects, or Yelp logging gaps as business death.

- A business is realistically considered failed/stressed only when:

  - It was ever open (IS_OPEN = 1)
  
  - It later showed long closure months (IS_OPEN = 0)
  
  - It remained closed for 6+ months or more
  
  - It shows stress behavior in the 3-month window before closure density spikes

- This definition is important because Yelp has no revenue field, no failure tag, and check-in logs are incomplete in some months. So stress detection had to rely on behavioral momentum, sentiment density, and stability loss, not internal financial truth.

**2. Data Source**

- The dataset used comes from the official Yelp Open Dataset. It was first uploaded into Azure storage, then ingested into Snowflake using external stages. Four JSON entity files were used: business profiles, reviews, users, and check-ins. Since Yelp does not provide revenue or a failure label, behavioral signals were engineered into analytical tables using SQL Notebook before modeling.

**https://business.yelp.com/data/resources/open-dataseta**

  - The dataset is delivered in JSON format and includes multiple entity files. For this project, four core files were used as analytical sources:
  
  - Business profiles(150,346 rows) → structural metadata of Yelp-listed businesses
  
  - Reviews(6,990,280 rows) → user-written feedback and star ratings
  
  - Users(1,987,897 rows) → reviewer metadata including elite status and platform age
  
  - Check-ins(131,930rows) → timestamp logs of visits to businesses

- Each file was first uploaded into Azure storage and then referenced into Snowflake using an external stage. The data was copied into VARIANT tables to preserve JSON structure before flattening into analytical staging tables.

**3. Data Processing**

- After loading raw JSON, structured analytical tables were built inside Snowflake SQL Notebook. Only essential fields were extracted, cast into clean types, deduplicated, null-handled, and then joined for modeling.Below are the four core tables: 

  - STG_YELP_BUSINESS cleaned by removing duplicate BUSINESS_ID entries (none found) and normalizing 103 missing category tags to UNKNOWN, while keeping NAME, CITY, STATE, STARS, REVIEW_COUNT, and OPENED fully       non-NULL.
  
  - STG_YELP_REVIEWS cleaned by deduplicating on REVIEW_ID using ROW_NUMBER and retaining 1 unique review per REVIEW_ID, with no missing BUSINESS_ID, USER_ID, or REVIEW_DATE, and sentiment polarity recomputed        for all reviews using TextBlob.
      - Three important Snowflake Python UDFs that generate sentiment intelligence:

        - ANALYZE_SENTIMENT(TEXT) → classified text into POSITIVE / NEGATIVE / NEUTRAL using polarity threshold (±0.2)
        
        - SENTIMENT(TEXT) → returns raw polarity score (-1 to +1 range)

        - FINAL_SENTIMENT → segmentation tag combining STARS and sentiment category
          
      - The final columns created for quantifying sentiments:
        
        - SENTIMENTS → POSITIVE / NEGATIVE / NEUTRAL label
          
        - SENTIMENT_SCORE → numeric polarity value
          
        - FINAL_SENTIMENT → STRONG POSITIVE / STRONG NEGATIVE / MISMATCH RISK / ANOMALY / NEUTRAL  
  
  - STG_YELP_USER cleaned by converting 189,669+ NULL or empty ELITE reviewer tags into NOT ELITE, ensuring no missing USER_ID or REVIEW_COUNT, and standardizing YELPING_SINCE into TIMESTAMP for account age          analysis.
  
  - STG_TBL_CHECKINS cleaned by removing duplicate visits on BUSINESS_ID + DATE_VISITED, keeping the latest timestamp per visit, and validating full check-in time range using MIN/MAX date sanity checks.

- The key analytical tables produced include:

  - STG_YELP_BUSINESS → BUSINESS_ID, NAME, CITY, STATE, STARS, REVIEW_COUNT, OPENED, CATEGORIES
  
  - STG_YELP_REVIEWS → BUSINESS_ID, REVIEW_ID, USER_ID, REVIEW_DATE, STARS, REVIEW_GIVEN, SENTIMENTS, FINAL_SENTIMENTS, SENTIMENT_SCORE
  
  - STG_YELP_USER → USER_ID, REVIEW_COUNT, ELITE, YELPING_SINCE, ELITE_REVIEWER_FLAG, USER_AGE_YEARS
  
  - STG_TBL_CHECKINS → BUSINESS_ID, DATE_VISITED

- Following features were created to convert public behavioral signals into measurable business-risk :
  
  - ANALYTICS_RESTAURANT_MONTHLY: Captures monthly customer review momentum, average star rating, and rating volatility for every business category, serving as the core satisfaction and demand signal table.

  - ANALYTICS_RESTAURANT_CHECKINS_MONTHLY: Aggregates monthly check-in volume per business, acting as a validated proxy for footfall, customer interest, and offline engagement momentum.
  
  - ANALYTICS_RESTAURANT_RATING_TREND: Applies 3-month lag window calculations on average ratings to measure rating slope movement and detect early satisfaction decline behavior.
   
  - ANALYTICS_RESTAURANT_SIGNAL_IMPORTANCE: Merges lag-based momentum deltas from reviews and check-ins with volatility behavior to engineer trend-driven risk signals instead of static attributes.
    
  - ANALYTICS_STRESS_TARGET: Generates the target label RATING_STRESS_FLAG using a 3-month rating drop threshold of −0.4 stars, ensuring stress is tagged only when a sustained negative slope appears.
    
- Following Hypothesis test tables were created for behavioral validation:

  - HYPOTHESIS_1_TEST → segments businesses into ENGAGEMENT_DROP vs NO_DROP based on median engagement score (reviews 60%, checkins 40%).
  
  - HYPOTHESIS_2_TEST → creates RATING_DOWN_FLAG and ENGAGEMENT_DOWN_FLAG using 1-month LAG difference.
  
  - HYPOTHESIS_3_TEST → groups businesses into HIGH_VOLATILITY vs LOW_VOLATILITY using median RATING_VOLATILITY.
  
  - HYPOTHESIS_4_TEST → tests open rate across popularity tiers (VERY_POPULAR, MED_POPULAR, LOW_POPULAR) and found static popularity does not predict closure direction.
  
  - HYPOTHESIS_5_ELITE_IMPACT → maps reviewer ELITE_FLAG, REVIEWER_AGE_YEARS, and influence grouping and found elite reviewers increase anomaly confidence but do not shift closure risk alone.
  
**4. Exploratory Data Analysis Observations**

i. Engagement Distributions & Social Dynamics

- The data follows a distinct Power-Law (Long-Tail) Distribution, typical of social platforms, which heavily influences modeling strategies:

  - Extreme Skewness: Review and check-in volumes are heavily right-skewed. A small "elite" percentage of businesses drive the vast majority of platform interactions, while most businesses occupy low-to-medium      engagement tiers.
  
  - Popularity vs. Risk: High interaction counts (popularity) do not correlate linearly with survival. The data proves that large businesses fail due to momentum collapse, not lack of size. Consequently, raw         popularity metrics must be scaled to avoid biasing models toward "famous" entities.
  
  - Category Overlap: Businesses frequently belong to multiple category tags. This necessitates category-wide modeling rather than isolated segment analysis to capture the full scope of competitive pressure.

ii. Rating Volatility & Signal Reliability

- Analysis of rating standard deviation (volatility) revealed that statistical noise often mimics stress signals in low-volume environments:

  - Volume-Dependent Volatility: Rating volatility spikes disproportionately when monthly review volume is low (e.g., a month with one 5-star and one 1-star review yields massive volatility). This makes              volatility a measure of data fragility rather than business stress in sparse datasets.
  
  - Weak Solo Predictor: When isolated, the difference in volatility between open and closed businesses was small (~2.6%). This confirms that volatility is a weak predictor on its own.
  
  - Contextual Stress Signal: Volatility becomes a reliable "stress indicator" only when conditioned on sufficient review volume or when paired with a collapse in engagement trends. It signals instability, not       necessarily immediate failure.

iii. Temporal Trends & Momentum (The "Stress Fingerprint")

- Hypothesis testing on lagged metrics confirmed that business failure is a non-linear process defined by specific "stress fingerprints" rather than static correlations:

  - Order of Operations: Lagged deltas (1-month and 3-month) show that Interest Stress (check-in decline) typically precedes Rating Stress (star decline).

  - Synchronized Collapse: A statistical "Kill Zone" emerges when three signals interact simultaneously:
  
    - Engagement Velocity drops (ENGAGEMENT_CHANGE < 0).
    
    - Rating Momentum turns negative (RATING_CHANGE_3M < -0.5).
    
    - Negative Sentiment surges.

  - Non-Linearity: Static correlations between review counts, stars, and closure status were weak. This validates that failure is driven by the slope of decline (momentum) rather than the absolute state of the       business.

iv. Sentiment & Semantic Pressure

- Text-based polarity scores (via TextBlob) provided a separable intelligence layer that corrected for quantitative bias:

  - Positive Polarity Bias: The dataset exhibits a global positive skew, consistent with human bias in public review platforms. Therefore, the presence of positive sentiment is a baseline, not a safety signal.
  
  - The Negative Threshold: Negative sentiment is rarely dominant in raw counts but acts as a critical "Stress Amplifier." Closure risk does not correlate with the mere presence of negativity, but rather when        the Negative Sentiment Ratio surges above 30% during a period of falling engagement.
  
  - Crowd Pressure: Statistically extreme negative-sentiment months (where polarity drops far below the global mean) serve as markers for "crowd emotional pressure events," which accelerate the momentum of           failure.

v. Segmentation & Environmental Risk

- Geographic and user-tier segmentation revealed external factors influencing the "Stress Severity":

  - City-Level Risk: Closed businesses cluster differently by city, indicating that stress emergence is location-dependent (likely due to local competition density), even if the mechanics of closure (momentum        loss) remain constant.
  
  - Elite Reviewers as Amplifiers: Elite reviewers do not inherently cause closure. Instead, they act as signal amplifiers, increasing the visibility of stress during anomaly months. Their activity validates the     severity of a decline but does not independently predict it.

**5. Hypothesis Testing**

- Five core behavioral hypotheses were tested, each designed to reflect real business stress signatures, not academic theory only.

**i.Hypothesis 1: Engagement collapse months are followed by lower ratings later**

- H1 p-value: 0

- This hypothesis tested whether businesses that drop below median engagement scores show lower ratings in future months. The result returned p-value ≈ 0, meaning the stressed group and stable group were statistically different. But the real interpretation is in trend behavior, not the p-value.

- Businesses in the ENGAGEMENT_DROP group showed:

  - Higher negative sentiment density in those months
  
  - Measurable rating decline in the next 3 months
  
  - Stronger stress concentration across all verticals, not only restaurants
  
  - Engagement drop was not a rare anomaly — it appeared consistently before closure density windows

- This validates a temporal cause-effect signature:

  -H1 confirms that businesses in the ENGAGEMENT_DROP group show a statistically different rating distribution compared to stable engagement businesses (p≈0). The separation is valid, but effect direction           appears with a lag, not as direct causation. Engagement decline frequently appears 1–3 months before rating momentum turns negative.

**ii. Hypothesis 2: 3-month rating decline is linked with engagement deceleration**

- H2 p-value: 0

- This hypothesis compared LAG(AVG_RATING,3) slope changes against engagement movement. Again, p ≈ 0, but more importantly:

  - Months where rating slope declined more than 0.4 stars over 3 months also showed review + check-in momentum collapse
  
  - Engagement velocity drop and rating slope decline were paired signatures, not separate behaviors

- Interpretation:

  - Customers lose interest when ratings fall
  
  - Rating stress is not emotional noise only, it comes with measurable momentum decline
 
- Conclusion

  - H2 validates that months with strong 3-month rating decline also show engagement deceleration (p≈0). Rating stress months and engagement stress months form paired behavioral signatures, meaning the model         must treat them as interacting trend signals, not isolated metrics.

**iii. Hypothesis 3: Businesses with unstable ratings have slightly higher closure density**
- H3 p value:0
 
- The segmentation results showed:

  - 19.57% of HIGH_VOLATILITY businesses were closed
  
  - 16.92% of LOW_VOLATILITY businesses were closed
  
  - Absolute lift only ≈ 2.65%

- Interpretation:
  
  - Volatility alone is weak. But volatility is a stress amplifier when combined with sentiment or momentum collapse.
  - So the conclusion becomes conditional: Volatility is useful only when other stress signals collapse or spike together
    
- Conclusion
  - H3 shows a small absolute closure lift (~2.65%) between HIGH_VOLATILITY and LOW_VOLATILITY businesses. This proves that volatility alone is weak, but becomes a meaningful stress amplifier when aligned with       engagement collapse or negative sentiment surge.

**iv. Hypothesis 4: Popular businesses do not close less or more by default**

- H4 p VALUE = 2.3 × 10⁻²⁶⁶

- That is extremely significant mathematically. But the segmentation table shows:

  - All popularity tiers had ~79–80% OPENED percentage
  
  - Closure % was nearly equal across all groups

- Interpretation:

  - Static popularity does not change closure probability
  
  - Popularity momentum decline over time is what matters, not static tiers

  - We learned that popularity as a trend signal, not a standalone closure protector

- Conclusion
  - H4 was the only hypothesis with an extreme p-value, but all popularity tiers showed nearly equal open rates (~79–80%). This proves that static popularity does not predict closure. Popularity is valuable only     as a trend feature when measuring momentum loss, not as a fixed survival indicator.

**v. Hypothesis 5: Elite reviewers influence stressed months more strongly, but don’t predict closure alone**

- H5 p value: 0
- Interpretation:

  - Elite reviewers mostly belong to older Yelp accounts and influence rating momentum direction in stressed months but elite reviewer flag does not shift closure risk alone

- Conclusion:

  - H5 confirms that elite reviewers increase signal confidence during stressed months (p≈0), but ELITE_REVIEWER_FLAG alone does not shift closure probability. Elite reviewer behavior strengthens anomaly             detection, not failure prediction by itself.

**6. Correlations Interpretation:**

- The correlations that mattered most were:
  
  - Engagement velocity vs rating slope decline
  
  - Negative sentiment ratio vs volatility spikes
  
  - Momentum collapse months vs future closure density

- These are trend-interaction correlations, not static ones.

- Interpretation :

  - Yelp risk signals behave non-linearly. Social behavioral data will rarely show strong Pearson correlation with a binary closure flag. The correct analytical interpretation is to engineer lag-based trend          deltas and test group lift behavior



