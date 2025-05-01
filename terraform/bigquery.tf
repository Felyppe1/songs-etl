resource "google_bigquery_dataset" "songs" {
    project = var.project
    dataset_id = "songs"
    description = "Dataset com todas as tabelas relacionadas a músicas, playlists, cantores, entre outros, para análise"
    location = var.region
}

resource "google_bigquery_table" "users" {
    project = var.project
    dataset_id = google_bigquery_dataset.songs.dataset_id
    table_id = "users"
    description = "Tabela de usuários das plataformas de música"
    schema = <<SCHEMA
    [
        {
            "name": "user_id",
            "description": "Identificador do usuário em uma plataforma específica",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Nome da pessoa (não precisa ser completo)",
            "type": "STRING"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "playlists" {
    project = var.project
    dataset_id = google_bigquery_dataset.songs.dataset_id
    table_id = "playlists"
    description = "Tabela das playlists dos usuários"
    schema = <<SCHEMA
    [
        {
            "name": "playlist_id",
            "description": "Identificador da playlist em uma plataforma específica",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Nome da playlist",
            "type": "STRING"
        },
        {
            "name": "description",
            "description": "Descrição da playlist",
            "type": "STRING"
        },
        {
            "name": "image",
            "description": "Url da imagem da playlist",
            "type": "STRING"
        },
        {
            "name": "user_id",
            "description": "Identificador do usuário dono da playlist",
            "type": "STRING"
        }
    ]
    SCHEMA
}

resource "google_bigquery_table" "tracks" {
    project = var.project
    dataset_id = google_bigquery_dataset.songs.dataset_id
    table_id = "tracks"
    description = "Tabela de músicas das playlists dos usuários"
    schema = <<SCHEMA
    [
        {
            "name": "track_id",
            "description": "Identificador da da música em uma plataforma específica",
            "type": "STRING"
        },
        {
            "name": "name",
            "description": "Nome da música",
            "type": "STRING"
        },
        {
            "name": "duration_ms",
            "description": "Tamanho da música em milissegundos",
            "type": "INTEGER"
        },
        {
            "name": "is_explicit",
            "description": "Flag para saber se a música é considerada explícita",
            "type": "BOOLEAN"
        },
        {
            "name": "added_at",
            "description": "Data do dia em que a música foi adicionda à playlist",
            "type": "STRING"
        },
        {
            "name": "is_local",
            "description": "Flag para saber se a música é um arquivo externo à plataforma",
            "type": "BOOLEAN"
        },
        {
            "name": "artist_id",
            "description": "Identificador do artista em uma plataforma específica",
            "type": "STRING"
        },
        {
            "name": "playlist_id",
            "description": "Identificador da playlist em uma plataforma específica",
            "type": "STRING"
        }
    ]
    SCHEMA
}