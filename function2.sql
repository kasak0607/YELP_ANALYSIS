CREATE OR REPLACE FUNCTION sentiment(text STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9'
PACKAGES = ('textblob')
HANDLER = 'analyzer'
AS $$
from textblob import TextBlob

def analyzer(text):
    if text is None:
        return 'Neutral'
    
    else:
       analysis = TextBlob(text)
       return analysis.sentiment.polarity
$$;
