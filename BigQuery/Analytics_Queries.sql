-- Creating the EMBEDDINGS for the summary and writing the results to a new Summary Table:
CREATE TABLE restaurant_review.restaurant_summary as (
SELECT id, name, address, description, ml_generate_embedding_result 
FROM ML.GENERATE_EMBEDDING(
 MODEL `restaurant_review.embeddings_model`,
 ( select id, name, address, description, description as content from(  
    SELECT id, name, address, IFNULL (prompt || IFNULL('The grades received as feedback and score against each grade: ' || STRING_AGG(overall_grade_and_score), ' '), 'None') as description FROM ( 
select DISTINCT a._id id, a.name, IFNULL(a.address.building, ' ') || ', ' || IFNULL(a.address.street,' ') || ', ' || IFNULL(a.address.zipcode, 0) || ', ' || IFNULL(a.borough, ' ') address, 
'This is a restaurant named: ' || a.name || ' situated at: ' || IFNULL(a.address.building, ' ') || ', ' || IFNULL(a.address.street,' ') || ', ' || IFNULL(a.address.zipcode, 0) || ', ' || ifnull(a.borough, ' ') || '. They serve the cuisine: ' || a.cuisine || '.' || ifnull('Some additional information on this restaurant: ' || a.summary || '.', ' ') || ifnull('Some additional information on this restaurant: ' || b.text || '.', ' ') as prompt,  grades.grade || ': ' || SUM(grades.score) OVER (PARTITION BY a._id, grades.grade) as overall_grade_and_score from restaurant_review.restaurants a left outer join restaurant_review.raw_reviews b
on a._id = b.restaurant_id, UNNEST(grades) AS grades ) GROUP BY id, name, address, prompt
 ))));


-- Vector Search and Gemini Validation of the match:
with user_query as (
   select 'Indian cuisine with the best rating' as query
)
select name, description, response,score,perc
 from (
SELECT name, description, ml_generate_text_llm_result as response,
SAFE_CAST(JSON_VALUE(replace(replace(ml_generate_text_llm_result,'```',''),'json',''), '$.match_score') AS FLOAT64) as score,
SAFE_CAST(JSON_VALUE(replace(replace(ml_generate_text_llm_result,'```',''),'json',''), '$.percentage_match') AS FLOAT64) as perc
FROM ML.GENERATE_TEXT(MODEL `abis-345004.restaurant_review.gemini_remote_model`,
   (select name, description, distance, concat('Your objective is to respond with a JSON object of 2 values (percentage_match and match_score) by comparing the result_description: ', description,' against the user_search_query: ', (SELECT query AS content from user_query), ' Your goal is to result: 1) Percentage of match of response to the user_search_query (percentage_match) and 2) Score for the match on a scale of 1 to 10  (match_score). Also remember that the grade and score value in the result_description represents customer feedback for the restaurant and a grade on a scale of A to Z with the corresponding score being the number of votes on it. You can use this information as the restaurant score for comparing against the user_search_query in addition to other details you have in the result_description field. Do not return any other text. Just the JSON object with 2 values - percentage_match and match_score on a scale of 1 to 10.') as prompt from (
select  query, base.id id, base.name name, base.description description, distance
from VECTOR_SEARCH(
 TABLE restaurant_review.restaurant_summary,
 'ml_generate_embedding_result',
(SELECT text_embedding, content 
     FROM ML.GENERATE_TEXT_EMBEDDING(
         MODEL `restaurant_review.embeddings_model`,
         (SELECT query AS content from user_query)) ),top_k => 25) )  X ),
STRUCT(
 TRUE AS flatten_json_output))
) order by perc desc;
