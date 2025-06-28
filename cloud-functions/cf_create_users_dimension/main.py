import functions_framework
from dotenv import load_dotenv
import pandas as pd
import os
import json
from datetime import date
from cuid2 import Cuid
from google.cloud import bigquery
from google.cloud import storage

load_dotenv(override=True)

PROJECT_ID = os.getenv('PROJECT_ID')
if not PROJECT_ID:
    raise ValueError("PROJECT_ID environment variable not set.")

DATASET_ID = os.getenv('DATASET_ID')
if not DATASET_ID:
    raise ValueError("DATASET_ID environment variable not set.")

TABLE_ID = os.getenv('TABLE_ID')
if not TABLE_ID:
    raise ValueError("TABLE_ID environment variable not set.")

CUID_GENERATOR: Cuid = Cuid(length=10)

def retrieve_object_from_bucket(bucket_name, object_path):
    try:
        client = storage.Client()

        bucket = client.get_bucket(bucket_name)
        blob = bucket.blob(object_path)
        json_data = blob.download_as_text()

        print(f"Object '{object_path}' retrieved.")
        return json.loads(json_data)

    except Exception as e:
        raise Exception(f"Error while getting objects from bucket: {e}")


def upload_dataframe_to_bigquery(df, dataset_table):
    client = bigquery.Client()

    table = client.get_table(dataset_table)
    schema = table.schema

    job_config = bigquery.LoadJobConfig(
        write_disposition='WRITE_TRUNCATE',
        schema=schema
    )

    try:
        job = client.load_table_from_dataframe(df, dataset_table, job_config=job_config)
        job.result()

        print(f'Dataframe uploaded to the BigQuery table: {dataset_table}.{PROJECT_ID}')

    except Exception as e:
        raise Exception(f'An error occurred while uploading dataframe to BigQuery: {e}')


def execute_bigquery_query(query):
    client = bigquery.Client()
    query_job = client.query(query)

    rows = query_job.result()

    return rows

@functions_framework.http
def main(request):
    print('Create user dimension...')

    users_df = execute_bigquery_query(
        """
        SELECT *
        FROM oltp_system.users
        """
    ).to_dataframe()

    users_df['dim_user_id'] = [CUID_GENERATOR.generate() for _ in range(len(users_df))]

    upload_dataframe_to_bigquery(
        users_df,
        f'{DATASET_ID}.{TABLE_ID}'
    )

    return 'Transformation completed.'
