import functions_framework
from dotenv import load_dotenv
from requests import post, get
import os
import json
from google.cloud import bigquery
from google.cloud import secretmanager

load_dotenv(override=True)

PROJECT_ID = os.getenv('PROJECT_ID')
if not PROJECT_ID:
    raise ValueError('PROJECT_ID environment variable is not set')

SONGS_SECRET_NAME = os.getenv('SONGS_SECRET_NAME')
if not SONGS_SECRET_NAME:
    raise ValueError('SONGS_SECRET_NAME environment variable is not set')

secretManagerClient = secretmanager.SecretManagerServiceClient()

request = { "name": f"projects/{PROJECT_ID}/secrets/{SONGS_SECRET_NAME}/versions/latest" }
response = secretManagerClient.access_secret_version(request)

credentials_str = response.payload.data.decode('UTF-8')
credentials = json.loads(credentials_str)

SPOTIFY_CLIENT_ID = credentials.get('spotify_client_id')
SPOTIFY_CLIENT_SECRET = credentials.get('spotify_client_secret')

# SPOTIFY_CLIENT_ID = os.getenv('SPOTIFY_CLIENT_ID')
# SPOTIFY_CLIENT_SECRET = os.getenv('SPOTIFY_CLIENT_SECRET')
# if not SPOTIFY_CLIENT_ID:
#     raise ValueError('SPOTIFY_CLIENT_ID environment variable not set.')
# if not SPOTIFY_CLIENT_SECRET:
#     raise ValueError('SPOTIFY_CLIENT_SECRET environment variable not set.')

SPOTIFY_ACCESS_TOKEN = None
SPOTIFY_BASE_URL = 'https://api.spotify.com/v1'

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

    try:
        client = storage.Client()
        bucket = client.get_bucket(bucket_name)

        blob = bucket.blob(destination_blob_name)
        blob.upload_from_string(json.dumps(json_data))

        print(f'JSON data uploaded to {bucket_name}/{destination_blob_name}')
    
    except Exception as e:
        raise Exception(f'Error uploading json to {bucket_name}: {str(e)}')

def query():
    client = bigquery.Client()
    query_job = client.query(f"""
        SELECT *
        FROM songs.users
    """)

    rows = query_job.result()

    return rows


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

def get_tracks_by_playlist_id(playlist_id, limit=100, offset=0):
    url = f'{SPOTIFY_BASE_URL}/playlists/{playlist_id}/tracks?limit={limit}&offset={offset}'

    headers = {
        'Authorization': f'Bearer {SPOTIFY_ACCESS_TOKEN}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()

    return response.json()


def extract():
    users = query()

    for user in users:
        print(f'User: {user["name"]}')

        print('Getting playlists')
        playlists = get_playlists_by_user_id(user['user_id'])

        playlists = {
            'user_id': user['user_id'],
            'data': playlists
        }

        print('Uploading playlists to the bucket')
        upload_json_to_bucket(
            bucket_name=f'landing-{PROJECT_ID}',
            json_data=playlists,
            destination_blob_name=f'playlists_by_user/user_id_{user["user_id"]}.json',
        )

        OFFSET = 100

        for playlist in playlists['data']['items']:
            all_tracks = []
            offset = 0

            while True:
                print(f'Getting {OFFSET} tracks from the playlist')
                tracks = get_tracks_by_playlist_id(playlist['id'], limit=OFFSET, offset=offset)

                all_tracks.extend(tracks['items'])
                
                if tracks['next'] == None:
                    break
                
                offset += OFFSET
            
            tracks = {
                'playlist_id': playlist['id'],
                'data': all_tracks
            }
            
            upload_json_to_bucket(
                bucket_name=f'landing-{PROJECT_ID}',
                json_data=tracks,
                destination_blob_name=f'tracks_by_playlist/playlist_id_{playlist["id"]}.json',
            )

        print()


@functions_framework.http
def main(request):
    get_access_token()

    extract()

    return 'Extraction completed.'
