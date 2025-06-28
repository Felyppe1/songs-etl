import functions_framework
from dotenv import load_dotenv
import pandas as pd
import pandas_gbq
import os
import json
from typing import List
from google.cloud.storage import Blob
from datetime import date
from cuid2 import Cuid
from google.cloud import bigquery
import asyncio


load_dotenv(override=True)

PROJECT_ID = os.getenv('PROJECT_ID')
if not PROJECT_ID:
    raise ValueError("PROJECT_ID environment variable not set.")

CUID_GENERATOR: Cuid = Cuid(length=10)

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

    return rows.to_dataframe()

###################################################################################
# Steps of the transformation
###################################################################################

async def create_fact_songs():
    print('CREATE FACT SONGS')

    users_playlists = retrieve_object_from_bucket(f'landing-{PROJECT_ID}', f'spotify/playlists/{date.today()}.json')
    playlists_tracks = retrieve_object_from_bucket(f'landing-{PROJECT_ID}', f'spotify/tracks/{date.today()}.json')

    dim_playlist_df = execute_bigquery_query("""
    SELECT *
    FROM fact_songs.dim_playlist
    """)
    dim_artist_df = execute_bigquery_query("""
    SELECT *
    FROM fact_songs.dim_artist
    """)
    dim_track_df = execute_bigquery_query("""
    SELECT *
    FROM fact_songs.dim_track
    """)
    dim_user_df = execute_bigquery_query("""
    SELECT *
    FROM fact_songs.dim_user
    """)
    users_df = execute_bigquery_query("""
    SELECT *
    FROM fact_songs.users
    """)

    songs = []

    for playlist_tracks in playlists_tracks:
        playlist_id = playlist_tracks['playlist_id']

        spotify_user_id = None

        for user_playlists in users_playlists:
            for playlist in user_playlists['playlists']:
                if playlist['id'] == playlist_id:
                    spotify_user_id = user_playlists['spotify_id']

                    break
        
        for track in playlist_tracks['tracks']:
            track_id = track['id']
            added_at = track['added_at']
            is_local = track['is_local']
            artists = track.get('artists', [])

            for artist in artists:
                songs.append({
                    'playlist_id': playlist_id,
                    'artist_id': artist['id'],
                    'track_id': track_id,
                    'spotify_id': spotify_user_id,
                    'dim_platform_id': 'spotify',
                    'is_local': is_local,
                    'added_at': added_at,
                })

    fact_songs_df = pd.DataFrame(songs).drop_duplicates()

    fact_songs_df = pd.merge(fact_songs_df, dim_playlist_df, how='left', on='playlist_id')
    fact_songs_df = pd.merge(fact_songs_df, dim_artist_df, how='left', on='artist_id')
    fact_songs_df = pd.merge(fact_songs_df, dim_track_df, how='left', on='track_id')

    fact_songs_df = pd.merge(fact_songs_df, users_df[['spotify_id', 'user_id']], how='left', on='spotify_id')
    fact_songs_df = pd.merge(fact_songs_df, dim_user_df[['user_id', 'dim_user_id']], how='left', on='user_id')
    
    fact_songs_df = fact_songs_df[[
        'dim_playlist_id',
        'dim_artist_id',
        'dim_track_id',
        'dim_user_id',
        'dim_platform_id',
        'added_at',
        'is_local',
    ]]

    fact_songs_df['added_at'] = pd.to_datetime(fact_songs_df['added_at'], errors='coerce')

    upload_dataframe_to_bigquery(fact_songs_df, 'fact_songs.fact_songs')

async def create_all_tables():
    await create_fact_songs()

@functions_framework.http
def main(request):
    asyncio.run(create_all_tables())

    return 'Transformation completed.'
