--Gemini Remote Model Creation
CREATE MODEL `restaurant_review.gemini_remote_model`
REMOTE WITH CONNECTION `us-central1.bq_llm_connection`
OPTIONS(ENDPOINT = 'gemini-1.5-pro');

--Embeddings Model Creation
create or replace model restaurant_review.embeddings_model 
REMOTE WITH CONNECTION `us-central1.bq_llm_connection`
OPTIONS(ENDPOINT = 'textembedding-gecko@latest');
