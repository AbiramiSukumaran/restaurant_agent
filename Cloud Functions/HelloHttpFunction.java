/* Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
*/

package gcfv2;

import java.io.BufferedWriter;
import com.google.cloud.bigquery.BigQuery;
import com.google.cloud.bigquery.BigQueryOptions;
import com.google.cloud.bigquery.FieldValueList;
import com.google.cloud.bigquery.Job;
import com.google.cloud.bigquery.JobId;
import com.google.cloud.bigquery.JobInfo;
import com.google.cloud.bigquery.QueryJobConfiguration;
import com.google.cloud.bigquery.TableResult;
import java.util.ArrayList;
import java.util.List;
import java.util.HashMap;
import java.util.UUID;
import com.google.cloud.functions.HttpFunction;
import com.google.cloud.functions.HttpRequest;
import com.google.cloud.functions.HttpResponse;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonArray;
import com.google.gson.JsonParser;

public class HelloHttpFunction implements HttpFunction {
  public void service(final HttpRequest request, final HttpResponse response) throws Exception {

	// Get the request body as a JSON object.
	JsonObject requestJson = new Gson().fromJson(request.getReader(), JsonObject.class);
	String searchText = requestJson.get("search").getAsString();
	BufferedWriter writer = response.getWriter();
	String query = "with user_query as ( " + 
 "  select '" + searchText + "' as query " + 
") " + 
"select name, description, response,score,perc " + 
 "from ( " + 
"SELECT name, description, ml_generate_text_llm_result as response, " + 
"SAFE_CAST(JSON_VALUE(replace(replace(ml_generate_text_llm_result,'```',''),'json',''),  '$.match_score') AS FLOAT64) as score, " + 
"SAFE_CAST(JSON_VALUE(replace(replace(ml_generate_text_llm_result,'```',''),'json',''), '$.percentage_match') AS FLOAT64) as perc " + 
"FROM ML.GENERATE_TEXT(MODEL `restaurant_review.gemini_remote_model`, " + 
 "  (select name, description, distance, concat('Your objective is to respond with a JSON object of 2 values (percentage_match and match_score) by comparing the result_description: ', description,' against the user_search_query: ', (SELECT query AS content from user_query), ' Your goal is to result: 1) Percentage of match of response to the user_search_query (percentage_match) and 2) Score for the match on a scale of 1 to 10  (match_score). Also remember that the grade and score value in the result_description represents customer feedback for the restaurant and a grade on a scale of A to Z with the corresponding score being number of votes on it. You can use this information as restaurant score for comparing against the user_search_query in addition to other details you have in the result_description field. Do not return any other text. Just the JSON object with 2 values - percentage_match and match_score on a scale of 1 to 10.') as prompt from ( " + 
"select  query, base.id id, base.name name, base.description description, distance " + 
"from VECTOR_SEARCH( " + 
 "TABLE restaurant_review.restaurant_summary, " + 
 "'ml_generate_embedding_result', " + 
"(SELECT text_embedding, content  " + 
 "    FROM ML.GENERATE_TEXT_EMBEDDING( " + 
  "       MODEL `restaurant_review.embeddings_model`, " + 
   "      (SELECT query AS content from user_query)) ),top_k => 25) )  X ), " + 
"STRUCT( " + 
 "TRUE AS flatten_json_output)) " + 
")order by perc desc limit 5;";
	
	BigQuery bigquery = BigQueryOptions.getDefaultInstance().getService();
	QueryJobConfiguration queryConfig =
	QueryJobConfiguration.newBuilder(query)
	.setUseLegacySql(false)
	.build();
	
	// Create a job ID so that we can safely retry.
  JobId jobId = JobId.of(UUID.randomUUID().toString());
  Job queryJob = bigquery.create(JobInfo.newBuilder(queryConfig).setJobId(jobId).build());

  // Wait for the query to complete.
  queryJob = queryJob.waitFor();

  // Check for errors
  if (queryJob == null) {
    throw new RuntimeException("Job no longer exists");
  } else if (queryJob.getStatus().getError() != null) {
    // You can also look at queryJob.getStatus().getExecutionErrors() for all
    // errors, not just the latest one.
    throw new RuntimeException(queryJob.getStatus().getError().toString());
  }

  // Get the results.
  TableResult result = queryJob.getQueryResults();
  String name = "";
  String description = "";
  JsonArray jsonArray = new JsonArray(); // Create a JSON array
  
  // Print all pages of the results.
  for (FieldValueList row : result.iterateAll()){
    name = row.get("name").getValue().toString();
	description = row.get("description").getValue().toString();
	JsonObject jsonObject = new JsonObject();
	jsonObject.addProperty("name", name);
    jsonObject.addProperty("description", description);
	jsonArray.add(jsonObject);
  }
  // Set the response content type and write the JSON array
            response.setContentType("application/json");
            writer.write(jsonArray.toString());
  
  }
}
