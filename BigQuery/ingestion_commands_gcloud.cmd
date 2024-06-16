1. Clone the JSONL files: Run the following CURL command from Cloud Shell Terminal (https://shell.cloud.google.com/?fromcloudshell=true) 

git clone https://github.com/AbiramiSukumaran/restaurant_agent

This will create a new project folder called "restaurant_agent"

2. Navigate into your new project folder say "restaurant_agent":

cd restaurant_agent
 
(How we got the JSONL:
a. Navigate into your new project folder say "restaurant_agent":

cd restaurant_agent

curl --location --request POST 'https://eu-central-1.aws.data.mongodb-api.com/app/data-rfmqj/endpoint/data/v1/action/find' \
--header 'Content-Type: application/json' \
--header 'Access-Control-Request-Headers: *' \
--header 'api-key: YOUR_API_KEY' \
--data-raw '{ "collection":"restaurants", "database":"sample_restaurants", "dataSource":"M0"
}' > restaurants.csv

curl --location --request POST 'https://eu-central-1.aws.data.mongodb-api.com/app/data-rfmqj/endpoint/data/v1/action/find' \
--header 'Content-Type: application/json' \
--header 'Access-Control-Request-Headers: *' \
--header 'api-key: YOUR_API_KEY' \
--data-raw '{ "collection":"raw_reviews", "database":"sample_restaurants", "dataSource":"M0"
}' > raw_reviews.csv

b. Open the csv, remove commas after each JSON line and correct the data as needed. 

c. Save the result as a JSONL file from your Cloud Shell Editor. Name it restaurants.jsonl and raw_reviews.jsonl respectively.

   You can skip steps a, b and c since we already have the JSONL files created for you in this github repo. 
  Feel free to clone them directly in your Cloud Shell machine by running the following command in your Cloud Shell Terminal as mentioned in steps above 1 and 2.
 )

3. Run the below command from Cloud Shell Terminal to create a BigQuery Dataset:

bq --location=us-central1 mk -d \
    --default_table_expiration 3600 \
    --description "This is my restaurant agent dataset." \
    restaurant_review

This creates a dataset named restaurant_review.

5. Now run the below command to create a table and load the data from the 2 JSONL files we created in the steps above:
Make sure to run the below commands from withing hte projetc folder "restaurant_agent" so the command can identify your JSONL files.
Make sure to replace YOUR_PROJECT_ID placeholder with your project id.
  
bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  --autodetect \
  YOUR_PROJECT_ID:restaurant_review.restaurants \
  restaurants.jsonl

bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  --autodetect \
  YOUR_PROJECT_ID:restaurant_review.raw_reviews \
  raw_reviews.jsonl

