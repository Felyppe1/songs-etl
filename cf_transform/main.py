import functions_framework
from dotenv import load_dotenv
from requests import post
import pandas as pd
import pandas_gbq
import os
import json
from typing import List
from google.cloud.storage import Blob

load_dotenv(override=True)

PROJECT = os.getenv('GCP_PROJECT_ID')
if not PROJECT:
    raise ValueError("GCP_PROJECT_ID environment variable not set.")

def retrieve_object_from_bucket(bucket_name, object_path):
    from google.cloud import storage
    
    try:
        client = storage.Client()

        bucket = client.get_bucket(bucket_name)
        blob = bucket.blob(object_path)
        object = blob.download_as_text()

        print(f"Object '{object_path}' retrieved.")
        return object

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
        pandas_gbq.to_gbq(df, dataset_table, PROJECT, if_exists='replace')
        print(f'Dataframe uploaded to the BigQuery table: {dataset_table}.{PROJECT}')

    except Exception as e:
        raise Exception(f'An error occurred while uploading dataframe to BigQuery: {e}')


def transform():
    playlists_df = pd.DataFrame(columns=['playlist_id', 'name', 'description', 'image', 'user_id'])

    user_playlists_blobs = retrieve_blobs_from_bucket('meu-primeiro-data-lake', 'bronze/playlists_by_user')

    for blob in user_playlists_blobs:
        user_playlists_json = blob.download_as_text()
        user_playlists = json.loads(user_playlists_json)

        for playlist in user_playlists['data']['items']:
            playlists_df.loc[len(playlists_df)] = [
                playlist['id'],
                playlist['name'],
                playlist['description'],
                playlist['images'][0]['url'],
                user_playlists['user_id'],
            ]

    upload_dataframe_to_bigquery(playlists_df, 'silver_songs.playlists')

    tracks_df = pd.DataFrame(columns=['track_id', 'name', 'duration_ms', 'is_explicit', 'added_at', 'is_local', 'artist_id', 'playlist_id'])

    playlist_tracks_blobs = retrieve_blobs_from_bucket('meu-primeiro-data-lake', 'bronze/tracks_by_playlist')

    for blob in playlist_tracks_blobs:
        playlist_tracks_json = blob.download_as_text()
        playlist_tracks = json.loads(playlist_tracks_json)

        for index, track in enumerate(playlist_tracks['data'], start=len(tracks_df)):
            tracks_df.loc[index] = {
                'track_id': track['track']['id'],
                'name': track['track']['name'],
                'duration_ms': track['track']['duration_ms'],
                'is_explicit': track['track']['explicit'],
                'added_at': track['added_at'],
                'is_local': track['is_local'],
                'artist_id': track['track']['artists'][0]['id'],
                'playlist_id': playlist_tracks['playlist_id'],
            }
    
    upload_dataframe_to_bigquery(tracks_df, 'silver_songs.tracks')

@functions_framework.http
def main(request):
    transform()

    return 'Transformation completed.'
