resource "google_bigquery_dataset" "fact_songs" {
    project = var.project
    dataset_id = "fact_songs"
    description = "Dataset for multidimensional modeling about playlists management by a user in a platform"
    location = var.region
}

resource "google_bigquery_table" "users" {
    project    = var.project
    dataset_id = google_bigquery_dataset.fact_songs.dataset_id
    table_id   = "users"
    description = "Table of users from music platforms"
    schema = <<SCHEMA
    [
        {
            "name": "user_id",
            "description": "User identifier",
            "type": "STRING"
        },
        {
            "name": "spotify_id",
            "description": "User identifier on the Spotify",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Person's name (does not need to be full)",
            "type": "STRING"
        }
    ]
    SCHEMA
}






resource "google_bigquery_dataset" "prep_songs_dimensions" {
    project = var.project
    dataset_id = "prep_songs_dimensions"
    description = "Dataset for the dimensions of the user's playlists management in a platform"
    location = var.region
}

resource "google_bigquery_table" "dim_platform" {
    project = var.project
    dataset_id = google_bigquery_dataset.prep_songs_dimensions.dataset_id
    table_id = "dim_platform"
    description = "Dimension table for platforms"
    schema = <<SCHEMA
    [
        {
            "name": "dim_platform_id",
            "description": "Surrogate key of the playlist",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Plataform name",
            "type": "STRING"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "dim_playlist" {
    project = var.project
    dataset_id = google_bigquery_dataset.prep_songs_dimensions.dataset_id
    table_id = "dim_playlist"
    description = "Dimension table for playlists"
    schema = <<SCHEMA
    [
        {
            "name": "dim_playlist_id",
            "description": "Surrogate key of the playlist",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Playlist name",
            "type": "STRING"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "dim_user" {
    project    = var.project
    dataset_id = google_bigquery_dataset.prep_songs_dimensions.dataset_id
    table_id   = "dim_user"
    description = "Dimension table for users"
    schema = <<SCHEMA
    [
        {
            "name": "dim_user_id",
            "description": "Surrogate key of the user",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "User name",
            "type": "STRING"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "dim_artist" {
    project    = var.project
    dataset_id = google_bigquery_dataset.prep_songs_dimensions.dataset_id
    table_id   = "dim_artist"
    description = "Dimension table for artists"
    schema = <<SCHEMA
    [
        {
            "name": "dim_artist_id",
            "description": "Surrogate key of the artist",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Artist name",
            "type": "STRING"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "dim_track" {
    project    = var.project
    dataset_id = google_bigquery_dataset.prep_songs_dimensions.dataset_id
    table_id   = "dim_track"
    description = "Dimension table for tracks"
    schema = <<SCHEMA
    [
        {
            "name": "dim_track_id",
            "description": "Surrogate key of the track",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Track name",
            "type": "STRING"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "prep_songs_dimensions" {
    project    = var.project
    dataset_id = google_bigquery_dataset.prep_songs_dimensions.dataset_id
    table_id   = "prep_songs_dimensions"
    description = "Fact table for songs added to playlists"
    clustering = [ "dim_platform_id", "dim_playlist_id", "dim_user_id" ]
    schema = <<SCHEMA
    [
        {
            "name": "dim_platform_id",
            "description": "Foreign key to dim_platform",
            "type": "STRING"
        },
        {
            "name": "dim_playlist_id",
            "description": "Foreign key to dim_playlist",
            "type": "STRING"
        },
        {
            "name": "dim_artist_id",
            "description": "Foreign key to dim_artist",
            "type": "STRING"
        },
        {
            "name": "dim_track_id",
            "description": "Foreign key to dim_track",
            "type": "STRING"
        },
        {
            "name": "dim_user_id",
            "description": "Foreign key to dim_user",
            "type": "STRING"
        },
        {
            "name": "added_at",
            "description": "Timestamp when the song was added",
            "type": "TIMESTAMP"
        },
        {
            "name": "is_local",
            "description": "Whether the song is a local file",
            "type": "BOOLEAN"
        }
    ]
    SCHEMA

    deletion_protection=false
}
