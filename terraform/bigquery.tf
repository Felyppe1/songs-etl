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
            "name": "spotify_id",
            "description": "User identifier on a specific platform",
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


resource "google_bigquery_table" "dim_platform" {
    project = var.project
    dataset_id = google_bigquery_dataset.fact_songs.dataset_id
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
            "name": "platform_id",
            "description": "Identifier of the platform",
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
    dataset_id = google_bigquery_dataset.fact_songs.dataset_id
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
            "name": "playlist_id",
            "description": "Identifier of the playlist in the platform",
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

resource "google_bigquery_table" "dim_date" {
    project    = var.project
    dataset_id = google_bigquery_dataset.fact_songs.dataset_id
    table_id   = "dim_date"
    description = "Dimension table for dates"
    schema = <<SCHEMA
    [
        {
            "name": "date_id",
            "description": "Date identifier (e.g., YYYYMMDD)",
            "type": "STRING"
        },
        {
            "name": "day",
            "description": "Day of the month",
            "type": "INTEGER"
        },
        {
            "name": "month",
            "description": "Month number",
            "type": "INTEGER"
        },
        {
            "name": "year",
            "description": "Year number",
            "type": "INTEGER"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "dim_user" {
    project    = var.project
    dataset_id = google_bigquery_dataset.fact_songs.dataset_id
    table_id   = "dim_user"
    description = "Dimension table for users"
    schema = <<SCHEMA
    [
        {
            "name": "user_id",
            "description": "Identifier of the user",
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
    dataset_id = google_bigquery_dataset.fact_songs.dataset_id
    table_id   = "dim_artist"
    description = "Dimension table for artists"
    schema = <<SCHEMA
    [
        {
            "name": "dim_artist_id",
            "description": "Surrogate key of the playlist",
            "type": "STRING"
        },
        {
            "name": "artist_id",
            "description": "Identifier of the artist in the platform",
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

resource "google_bigquery_table" "fact_songs" {
    project    = var.project
    dataset_id = google_bigquery_dataset.fact_songs.dataset_id
    table_id   = "fact_songs"
    description = "Fact table for songs added to playlists"
    schema = <<SCHEMA
    [
        {
            "name": "platform_id",
            "description": "Foreign key to dim_platform",
            "type": "STRING"
        },
        {
            "name": "playlist_id",
            "description": "Foreign key to dim_playlist",
            "type": "STRING"
        },
        {
            "name": "artist_id",
            "description": "Foreign key to dim_artist",
            "type": "STRING"
        },
        {
            "name": "user_id",
            "description": "Foreign key to dim_user",
            "type": "STRING"
        },
        {
            "name": "date_id",
            "description": "Foreign key to dim_date",
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
        },
        {
            "name": "position_in_playlist",
            "description": "Position of the song in the playlist",
            "type": "INTEGER"
        }
    ]
    SCHEMA
}
