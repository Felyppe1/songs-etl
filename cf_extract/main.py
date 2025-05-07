import functions_framework
from dotenv import load_dotenv
from requests import post, get
import os
import json
from google.cloud import bigquery
from google.cloud import secretmanager
from typing import Dict, Iterator
from datetime import date

load_dotenv(override=True)

PROJECT_ID = os.getenv('PROJECT_ID')
if not PROJECT_ID:
    raise ValueError('PROJECT_ID environment variable is not set')

SONGS_SECRET_NAME = os.getenv('SONGS_SECRET_NAME')
if not SONGS_SECRET_NAME:
    raise ValueError('SONGS_SECRET_NAME environment variable is not set')

SPOTIFY_CLIENT_ID = None
SPOTIFY_CLIENT_SECRET = None
SPOTIFY_ACCESS_TOKEN = None
SPOTIFY_BASE_URL = 'https://api.spotify.com/v1'


###################################################################################
# Functions to interact with the GCP
###################################################################################

def upload_object_to_bucket(bucket_name, source_file, destination_blob_name):
    from google.cloud import storage

    try:
        client = storage.Client() # There is no need to use from_service_account_json because in the CF it can authenticate normally.
        bucket = client.get_bucket(bucket_name)

        blob = bucket.blob(destination_blob_name)
        blob.upload_from_filename(source_file)

        print(f'File {source_file} uploaded to {bucket_name}/{destination_blob_name}')
    
    except Exception as e:
        raise Exception(f'Error uploading object to {bucket_name}: {str(e)}')

def upload_json_to_bucket(bucket_name, json_data, destination_blob_name):
    from google.cloud import storage

    if destination_blob_name[0] == '/':
        destination_blob_name = destination_blob_name[1:]

    try:
        client = storage.Client()
        bucket = client.get_bucket(bucket_name)

        blob = bucket.blob(destination_blob_name)
        blob.upload_from_string(json.dumps(json_data))

        print(f'JSON data uploaded to {bucket_name}/{destination_blob_name}')
    
    except Exception as e:
        raise Exception(f'Error uploading json to {bucket_name}: {str(e)}')
    
def iterate_object_from_bucket(bucket_name, object_path) -> Iterator[Dict]:
    from google.cloud import storage
    
    try:
        client = storage.Client()

        bucket = client.get_bucket(bucket_name)
        blobs = bucket.list_blobs(prefix=object_path)

        for blob in blobs:
            blob_json = blob.download_as_text()
            blob_dict = json.loads(blob_json)

            yield blob_dict

        print(f"Data from '{object_path}' retrieved.")

    except Exception as e:
        raise Exception(f"Error while getting blobs from bucket: {e}")
    
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
    
def get_users_from_bigquery():
    client = bigquery.Client()
    query_job = client.query(f"""
        SELECT *
        FROM fact_songs.users
    """)

    rows = query_job.result()

    return rows

def get_secret_manager_secret():
    global SPOTIFY_CLIENT_ID
    global SPOTIFY_CLIENT_SECRET

    print('Getting secret manager secret')
    
    secretManagerClient = secretmanager.SecretManagerServiceClient()

    request = { "name": f"projects/{PROJECT_ID}/secrets/{SONGS_SECRET_NAME}/versions/latest" }
    response = secretManagerClient.access_secret_version(request)

    credentials = json.loads(response.payload.data.decode('UTF-8'))

    SPOTIFY_CLIENT_ID = credentials.get('spotify_client_id')
    SPOTIFY_CLIENT_SECRET = credentials.get('spotify_client_secret')

###################################################################################
# Functions to interact with the Spotify API
###################################################################################

def get_access_token():
    global SPOTIFY_ACCESS_TOKEN

    url = 'https://accounts.spotify.com/api/token'

    headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
    }

    data = {
        'grant_type': 'client_credentials',
        'client_id': SPOTIFY_CLIENT_ID,
        'client_secret': SPOTIFY_CLIENT_SECRET,
    }

    response = post(url, headers=headers, data=data)
    response.raise_for_status()
    SPOTIFY_ACCESS_TOKEN = response.json()['access_token']

def get_an_artist_by_id(artist_id):
    url = f'{SPOTIFY_BASE_URL}/artists/{artist_id}'

    headers = {
        'Authorization': f'Bearer {SPOTIFY_ACCESS_TOKEN}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def get_all_albums_by_artist_id(artist_id):
    artist = get_an_artist_by_id(artist_id)

    url = f'{SPOTIFY_BASE_URL}/artists/{artist_id}/albums?include_groups=album'

    headers = {
        'Authorization': f'Bearer {SPOTIFY_ACCESS_TOKEN}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()

    print(f'Getting albums from artist: {artist["name"]}')

    return response.json()

def get_playlists_by_user_id(user_id):
    url = f'{SPOTIFY_BASE_URL}/users/{user_id}/playlists'

    headers = {
        'Authorization': f'Bearer {SPOTIFY_ACCESS_TOKEN}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()

    return response.json()

def get_tracks_by_playlist_id(playlist_id, limit=100, offset=0, fields=''):
    url = f'{SPOTIFY_BASE_URL}/playlists/{playlist_id}/tracks?limit={limit}&offset={offset}&fields={fields}'

    headers = {
        'Authorization': f'Bearer {SPOTIFY_ACCESS_TOKEN}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()

    return response.json()


###################################################################################
# Steps of the extraction
###################################################################################

def extract_spotify_playlists():
    print('Extract Spotify playlists')

    print('Getting users from BigQuery')
    users = get_users_from_bigquery()

    all_playlists = []

    for user in users:
        print(f'Getting playlists from user: {user["name"]}')
        playlists = get_playlists_by_user_id(user['spotify_id'])

        playlists_dict = {
            'user_id': user['spotify_id'],
            'playlists': playlists['items']
        }

        all_playlists.append(playlists_dict)

    print('Uploading playlists to the bucket')
    upload_json_to_bucket(
        bucket_name=f'landing-{PROJECT_ID}',
        json_data=all_playlists,
        destination_blob_name=f'spotify/playlists/{date.today()}.json',
    )

def extract_spotify_tracks():
    print('Extract Spotify tracks')

    LIMIT = 100

    print('Getting users playlists from the bucket')    
    users_playlists = retrieve_object_from_bucket(f'landing-{PROJECT_ID}', f'spotify/playlists/{date.today()}.json')

    all_playlists = []

    for user_playlists in users_playlists:
        for playlist in user_playlists['playlists']:
            all_tracks = []
            offset = 0

            while True:
                tracks = get_tracks_by_playlist_id(playlist['id'], limit=LIMIT, offset=offset)
                print(f'Got {len(tracks["items"])} tracks from the playlist {playlist["id"]}')

                # all_tracks.extend(tracks['items'])

                for track in tracks['items']:
                    # print(track['track']['name'], track['track']['album']['total_tracks'])

                    all_tracks.append({
                        'added_at': track['added_at'],
                        'is_local': track['is_local'],
                        'id': track['track']['id'],
                        'name': track['track']['name'],
                        'duration_ms': track['track']['duration_ms'],
                        'explicit': track['track']['explicit'],
                        'album': {
                            'id': track['track']['album']['id'],
                            'name': track['track']['album']['name'],
                            'release_date': track['track']['album']['release_date'],
                            'total_tracks': track['track']['album']['total_tracks'],
                            'images': track['track']['album']['images'],
                        },
                        'artists': [
                            {
                                'id': artist['id'],
                                'name': artist['name']
                            }
                            for artist in track['track']['artists']
                        ]
                    })
                
                if tracks['next'] == None:
                    break
                
                offset += LIMIT
            
            tracks = {
                'playlist_id': playlist['id'],
                'data': all_tracks
            }

            all_playlists.append(tracks)
    
    print('Uploading tracks to the bucket')
    upload_json_to_bucket(
        bucket_name=f'landing-{PROJECT_ID}',
        json_data=all_playlists,
        destination_blob_name=f'spotify/tracks/{date.today()}.json',
    )



@functions_framework.http
def main(request):
    get_secret_manager_secret()

    get_access_token()

    extract_spotify_playlists()

    extract_spotify_tracks()

    return 'Extraction completed.'
