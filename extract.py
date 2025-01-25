from dotenv import load_dotenv
from requests import post, get
import os
import json

load_dotenv(override=True)

BEYONCE_ID = '6vWDO969PvNqNYHIOW5v0m'
SPOTIFY_BASE_URL = 'https://api.spotify.com/v1'
USER_IDS = [
    { 'name': 'Bruna', 'id': 'vo3yf0r7oen9jj4f5393oyuwf' },
    { 'name': 'Felyppe', 'id': 'felyppe123' },
    { 'name': 'Isaac', 'id': '721howy7jowgka4xexlqfm9cm' }
]

def get_access_token():
    url = 'https://accounts.spotify.com/api/token'

    headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
    }

    data = {
        'grant_type': 'client_credentials',
        'client_id': os.environ['SPOTIFY_CLIENT_ID'],
        'client_secret': os.environ['SPOTIFY_CLIENT_SECRET'],
    }

    response = post(url, headers=headers, data=data)
    response.raise_for_status()
    print(response.json())

def upload_object_to_bucket(bucket_name, source_file, destination_blob_name, service_account_file):
    from google.cloud import storage

    try:
        client = storage.Client.from_service_account_json(service_account_file)
        bucket = client.get_bucket(bucket_name)

        blob = bucket.blob(destination_blob_name)
        blob.upload_from_filename(source_file)

        print(f'File {source_file} uploaded to {bucket_name}/{destination_blob_name}')
    
    except Exception as e:
        print(f'Error uploading file: {str(e)}')

def upload_json_to_bucket(bucket_name, json_data, destination_blob_name, service_account_file):
    from google.cloud import storage

    try:
        client = storage.Client.from_service_account_json(service_account_file)
        bucket = client.get_bucket(bucket_name)

        blob = bucket.blob(destination_blob_name)
        blob.upload_from_string(json.dumps(json_data))

        print(f'JSON data uploaded to {bucket_name}/{destination_blob_name}')
    
    except Exception as e:
        print(f'Error uploading data: {str(e)}')
        raise e


def get_an_artist_by_id(artist_id):
    url = f'{SPOTIFY_BASE_URL}/artists/{artist_id}'

    headers = {
        'Authorization': f'Bearer {os.environ["SPOTIFY_ACCESS_TOKEN"]}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def get_all_albums_by_artist_id(artist_id):
    artist = get_an_artist_by_id(artist_id)

    url = f'{SPOTIFY_BASE_URL}/artists/{artist_id}/albums?include_groups=album'

    headers = {
        'Authorization': f'Bearer {os.environ["SPOTIFY_ACCESS_TOKEN"]}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()

    print(f'Getting albums from artist: {artist["name"]}')

    return response.json()

def get_playlists_by_user_id(user_id):
    url = f'{SPOTIFY_BASE_URL}/users/{user_id}/playlists'

    headers = {
        'Authorization': f'Bearer {os.environ["SPOTIFY_ACCESS_TOKEN"]}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()

    return response.json()

def get_tracks_by_playlist_id(playlist_id, limit=100, offset=0):
    url = f'{SPOTIFY_BASE_URL}/playlists/{playlist_id}/tracks?limit={limit}&offset={offset}'

    headers = {
        'Authorization': f'Bearer {os.environ["SPOTIFY_ACCESS_TOKEN"]}'
    }

    response = get(url, headers=headers)
    response.raise_for_status()

    return response.json()


# get_access_token()

for user in USER_IDS:
    playlist_with_most_songs = None
    total_songs = 0

    playlists = get_playlists_by_user_id(user['id'])
    for playlist in playlists['items']:

        playlist_total_songs = playlist['tracks']['total']

        if playlist_total_songs > total_songs:
            playlist_with_most_songs = playlist
            total_songs = playlist_total_songs

    print(f'User: {user["name"]}')
    if playlist_with_most_songs:
        upload_json_to_bucket(
            bucket_name='meu-primeiro-data-lake',
            json_data=playlist_with_most_songs,
            destination_blob_name=f'bronze/playlists/playlist_id_{playlist_with_most_songs["id"]}.json',
            service_account_file=os.path.join(os.path.dirname(__file__), 'gcp-sa-credentials.json')
        )
        all_tracks = []
        offset = 0

        while True:
            tracks = get_tracks_by_playlist_id(playlist_with_most_songs['id'], limit=100, offset=offset)
            if tracks['next'] == None:
                break
            
            all_tracks.extend(tracks['items'])
            offset += 100
        
        upload_json_to_bucket(
            bucket_name='meu-primeiro-data-lake',
            json_data=all_tracks,
            destination_blob_name=f'bronze/tracks_by_playlist/playlist_id_{playlist_with_most_songs["id"]}.json',
            service_account_file=os.path.join(os.path.dirname(__file__), 'gcp-sa-credentials.json')
        )

    print()