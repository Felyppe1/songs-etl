import pandas as pd
import pandas_gbq
import os
import json

def retrieve_object_from_bucket(bucket_name, object_path, service_account_file):
    from google.cloud import storage
    
    try:
        client = storage.Client.from_service_account_json(service_account_file)

        bucket = client.get_bucket(bucket_name)

        blob = bucket.blob(object_path)
        object = blob.download_as_text()

        df = pd.read_json(object)

        print(f"Object '{object_path}' retrieved.")

        return df

    except Exception as e:
        print(f"Error: {e}")

def transform_data(df):
    pd.set_option('display.max_columns', None)
    artist_id = df['artist_id'].iloc[0]
    df = pd.json_normalize(df['items'])
    df = df[['id', 'name', 'total_tracks', 'release_date']].rename(columns={'id': 'album_id'})
    df['artist_id'] = artist_id

    return df

def upload_dataframe_to_bigquery(df, dataset_table, project):
    try:
        pandas_gbq.to_gbq(df, dataset_table, project)
        print(f'Dataframe uploaded to the BigQuery table: {dataset_table}.{project}')

    except Exception as e:
        print(f'An error occurred while uploading dataframe to BigQuery: {e}')


df = retrieve_object_from_bucket(
    bucket_name='meu-primeiro-data-lake', 
    object_path='bronze/albums/beyonce.json', 
    service_account_file=os.path.join(os.path.dirname(__file__), 'gcp-sa-credentials.json')
)
df = transform_data(df)
upload_dataframe_to_bigquery(df, 'silver_songs.albums', 'dynamic-art-447720-t2')
