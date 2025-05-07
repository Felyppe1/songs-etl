import functions_framework
from dotenv import load_dotenv
import pandas as pd
import pandas_gbq
import os
import json
from typing import List
from google.cloud.storage import Blob
from datetime import date


load_dotenv(override=True)

PROJECT_ID = os.getenv('PROJECT_ID')
if not PROJECT_ID:
    raise ValueError("PROJECT_ID environment variable not set.")

USER_PLAYLISTS_BLOBS = None
PLAYLIST_TRACKS_BLOBS = None

USERS_PLAYLISTS = None
PLAYLISTS_TRACKS = None


###################################################################################
# Functions to interact with the GCP
###################################################################################

def retrieve_object_from_bucket(bucket_name, object_path):
    from google.cloud import storage
    
    try:
        client = storage.Client()

        bucket = client.get_bucket(bucket_name)
        blob = bucket.blob(object_path)
        json_data = blob.download_as_text()

        print(f"Object '{object_path}' retrieved.")
        return json.loads(json_data)

    except Exception as e:
        raise Exception(f"Error while getting objects from bucket: {e}")

def retrieve_blobs_from_bucket(bucket_name, object_path) -> List[Blob]:
    from google.cloud import storage
    
    try:
        client = storage.Client()

        bucket = client.get_bucket(bucket_name)
        blobs = bucket.list_blobs(prefix=object_path)

        print(f"Blobs from '{object_path}' retrieved.")
        return blobs

    except Exception as e:
        raise Exception(f"Error while getting blobs from bucket: {e}")

def upload_dataframe_to_bigquery(df, dataset_table):
    try:
        pandas_gbq.to_gbq(df, dataset_table, PROJECT_ID, if_exists='replace')
        print(f'Dataframe uploaded to the BigQuery table: {dataset_table}.{PROJECT_ID}')

    except Exception as e:
        raise Exception(f'An error occurred while uploading dataframe to BigQuery: {e}')


###################################################################################
# Steps of the transformation
###################################################################################

def create_playlist_dimension():
    playlists_df = pd.DataFrame(columns=['playlist_id', 'name'])

    for user_playlists in USERS_PLAYLISTS:
        # print(json.dumps(user_playlists, indent=2))

        user_playlists_df = pd.DataFrame({
            'playlist_id': [playlist['id'] for playlist in user_playlists['playlists']],
            'name': [playlist['name'] for playlist in user_playlists['playlists']],
        })

        playlists_df = pd.concat([playlists_df, user_playlists_df], axis=0)
    
    upload_dataframe_to_bigquery(playlists_df, 'fact_songs.dim_playlist')

def create_artist_dimension():
    dim_artists_df = pd.DataFrame(columns=['artist_id', 'name'])

    for playlist_tracks in PLAYLISTS_TRACKS:
        for tracks in playlist_tracks['data']:
            artists_df = pd.DataFrame({
                'artist_id': [artist['id'] for artist in tracks['artists']],
                'name': [artist['name'] for artist in tracks['artists']],
            })

            dim_artists_df = pd.concat([dim_artists_df, artists_df])
    
    dim_artists_df = pd.DataFrame(dim_artists_df).drop_duplicates()

    upload_dataframe_to_bigquery(dim_artists_df, 'fact_songs.dim_artist')


@functions_framework.http
def main(request):
    global USERS_PLAYLISTS
    global PLAYLISTS_TRACKS

    USERS_PLAYLISTS = retrieve_object_from_bucket(f'landing-{PROJECT_ID}', f'spotify/playlists/{date.today()}.json')
    PLAYLISTS_TRACKS = retrieve_object_from_bucket(f'landing-{PROJECT_ID}', f'spotify/tracks/{date.today()}.json')

    create_playlist_dimension()
    create_artist_dimension()

    return 'Transformation completed.'
