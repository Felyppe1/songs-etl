data "archive_file" "extract_function_zip" {
    type = "zip"
    source_dir = "${path.module}/../cloud-functions/cf_extract"
    output_path = "${path.module}/deploy/cf_extract.zip"
}

resource "google_storage_bucket_object" "extract_function_object" {
    source = data.archive_file.extract_function_zip.output_path
    content_type = "application/zip"
    name = "extract-${data.archive_file.extract_function_zip.output_md5}.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.extract_function_zip
    ]
}

resource "google_cloudfunctions2_function" "extract_cloud_function" {
    name = "spotify-extract"
    location = var.region
    project = var.project
    description = "Cloud function created through terraform to extract data from Spotify"

    build_config {
        runtime = "python312"
        entry_point = "main"

        source {
            storage_source {
                bucket = google_storage_bucket.cloud_functions_bucket.name
                object = google_storage_bucket_object.extract_function_object.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory = "256M"
        timeout_seconds = 400
        service_account_email = google_service_account.cloud_functions_service_account.email
        environment_variables = {
            PROJECT_ID = "${var.project}"
            SONGS_SECRET_NAME = "${var.songs_secret_manager_name}"
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudfunctions.googleapis.com"]
    ]
}



###################################################################################################################
# CREATE FACT TABLE
###################################################################################################################

data "archive_file" "transform_function_zip" {
    type = "zip"
    source_dir = "${path.module}/../cloud-functions/cf_transform"
    output_path = "${path.module}/deploy/cf_transform.zip"
}

resource "google_storage_bucket_object" "transform_function_object" {
    source = data.archive_file.transform_function_zip.output_path
    content_type = "application/zip"
    name = "transform-${data.archive_file.extract_function_zip.output_md5}.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.transform_function_zip
    ]
}

resource "google_cloudfunctions2_function" "transform_cloud_function" {
    name = "spotify-transform"
    location = var.region
    project = var.project
    description = "Cloud function created through terraform to transform Spotify's data in the bucket and through it into the BigQuery"

    build_config {
        runtime = "python312"
        entry_point = "main"

        source {
            storage_source {
                bucket = google_storage_bucket.cloud_functions_bucket.name
                object = google_storage_bucket_object.transform_function_object.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory   = "1Gi"
        available_cpu      = "0.583"
        timeout_seconds = 400
        environment_variables = {
            PROJECT_ID = "${var.project}"
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudfunctions.googleapis.com"]
    ]
}



###################################################################################################################
# CREATE ARTISTS DIMENSION
###################################################################################################################

data "archive_file" "create_artists_dimensions_zip" {
    type = "zip"
    source_dir = "${path.module}/../cloud-functions/cf_create_artists_dimension"
    output_path = "${path.module}/deploy/cf_create_artists_dimension.zip"
}

resource "google_storage_bucket_object" "create_artists_dimension_object" {
    source = data.archive_file.create_artists_dimensions_zip.output_path
    content_type = "application/zip"
    name = "create-artists-dimension-${data.archive_file.create_artists_dimensions_zip.output_md5}.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.create_artists_dimensions_zip
    ]
}

resource "google_cloudfunctions2_function" "create_artists_dimension_function" {
    name = "create-artists-dimension"
    location = var.region
    project = var.project
    description = "Cloud function to create the artists dimension in BigQuery"

    build_config {
        runtime = "python312"
        entry_point = "main"

        source {
            storage_source {
                bucket = google_storage_bucket.cloud_functions_bucket.name
                object = google_storage_bucket_object.create_artists_dimension_object.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory   = "1Gi"
        available_cpu      = "0.583"
        timeout_seconds = 400
        environment_variables = {
            PROJECT_ID = "${var.project}"
            DATASET_ID = google_bigquery_dataset.prep_songs_dimensions.dataset_id
            TABLE_ID = google_bigquery_table.dim_artist.table_id
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudfunctions.googleapis.com"],
        google_bigquery_dataset.prep_songs_dimensions,
        google_bigquery_table.dim_artist
    ]
}

###################################################################################################################
# CREATE PLATFORMS DIMENSION
###################################################################################################################

data "archive_file" "create_platforms_dimension_zip" {
    type = "zip"
    source_dir = "${path.module}/../cloud-functions/cf_create_plataforms_dimension"
    output_path = "${path.module}/deploy/cf_create_platforms_dimension.zip"
}

resource "google_storage_bucket_object" "create_platforms_dimension_object" {
    source = data.archive_file.create_platforms_dimension_zip.output_path
    content_type = "application/zip"
    name = "create-platforms-dimension-${data.archive_file.create_platforms_dimension_zip.output_md5}.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.create_platforms_dimension_zip
    ]
}

resource "google_cloudfunctions2_function" "create_platforms_dimension_function" {
    name = "create-platforms-dimension"
    location = var.region
    project = var.project
    description = "Cloud function to create the platforms dimension in BigQuery"

    build_config {
        runtime = "python312"
        entry_point = "main"

        source {
            storage_source {
                bucket = google_storage_bucket.cloud_functions_bucket.name
                object = google_storage_bucket_object.create_platforms_dimension_object.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory   = "1Gi"
        available_cpu      = "0.583"
        timeout_seconds = 400
        environment_variables = {
            PROJECT_ID = "${var.project}"
            DATASET_ID = google_bigquery_dataset.prep_songs_dimensions.dataset_id
            TABLE_ID = google_bigquery_table.dim_platform.table_id
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudfunctions.googleapis.com"],
        google_bigquery_dataset.prep_songs_dimensions,
        google_bigquery_table.dim_platform
    ]
}

###################################################################################################################
# CREATE PLAYLISTS DIMENSION
###################################################################################################################

data "archive_file" "create_playlists_dimension_zip" {
    type = "zip"
    source_dir = "${path.module}/../cloud-functions/cf_create_playlists_dimension"
    output_path = "${path.module}/deploy/cf_create_playlists_dimension.zip"
}

resource "google_storage_bucket_object" "create_playlists_dimension_object" {
    source = data.archive_file.create_playlists_dimension_zip.output_path
    content_type = "application/zip"
    name = "create-playlists-dimension-${data.archive_file.create_playlists_dimension_zip.output_md5}.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.create_playlists_dimension_zip
    ]
}

resource "google_cloudfunctions2_function" "create_playlists_dimension_function" {
    name = "create-playlists-dimension"
    location = var.region
    project = var.project
    description = "Cloud function to create the playlists dimension in BigQuery"

    build_config {
        runtime = "python312"
        entry_point = "main"

        source {
            storage_source {
                bucket = google_storage_bucket.cloud_functions_bucket.name
                object = google_storage_bucket_object.create_playlists_dimension_object.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory   = "1Gi"
        available_cpu      = "0.583"
        timeout_seconds = 400
        environment_variables = {
            PROJECT_ID = "${var.project}"
            DATASET_ID = google_bigquery_dataset.prep_songs_dimensions.dataset_id
            TABLE_ID = google_bigquery_table.dim_playlist.table_id
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudfunctions.googleapis.com"],
        google_bigquery_dataset.prep_songs_dimensions,
        google_bigquery_table.dim_playlist
    ]
}

###################################################################################################################
# CREATE TRACKS DIMENSION
###################################################################################################################

data "archive_file" "create_tracks_dimension_zip" {
    type = "zip"
    source_dir = "${path.module}/../cloud-functions/cf_create_tracks_dimension"
    output_path = "${path.module}/deploy/cf_create_tracks_dimension.zip"
}

resource "google_storage_bucket_object" "create_tracks_dimension_object" {
    source = data.archive_file.create_tracks_dimension_zip.output_path
    content_type = "application/zip"
    name = "create-tracks-dimension-${data.archive_file.create_tracks_dimension_zip.output_md5}.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.create_tracks_dimension_zip
    ]
}

resource "google_cloudfunctions2_function" "create_tracks_dimension_function" {
    name = "create-tracks-dimension"
    location = var.region
    project = var.project
    description = "Cloud function to create the tracks dimension in BigQuery"

    build_config {
        runtime = "python312"
        entry_point = "main"

        source {
            storage_source {
                bucket = google_storage_bucket.cloud_functions_bucket.name
                object = google_storage_bucket_object.create_tracks_dimension_object.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory   = "1Gi"
        available_cpu      = "0.583"
        timeout_seconds = 400
        environment_variables = {
            PROJECT_ID = "${var.project}"
            DATASET_ID = google_bigquery_dataset.prep_songs_dimensions.dataset_id
            TABLE_ID = google_bigquery_table.dim_track.table_id
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudfunctions.googleapis.com"],
        google_bigquery_dataset.prep_songs_dimensions,
        google_bigquery_table.dim_track
    ]
}

###################################################################################################################
# CREATE USERS DIMENSION
###################################################################################################################

data "archive_file" "create_users_dimension_zip" {
    type = "zip"
    source_dir = "${path.module}/../cloud-functions/cf_create_users_dimension"
    output_path = "${path.module}/deploy/cf_create_users_dimension.zip"
}

resource "google_storage_bucket_object" "create_users_dimension_object" {
    source = data.archive_file.create_users_dimension_zip.output_path
    content_type = "application/zip"
    name = "create-users-dimension-${data.archive_file.create_users_dimension_zip.output_md5}.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.create_users_dimension_zip
    ]
}

resource "google_cloudfunctions2_function" "create_users_dimension_function" {
    name = "create-users-dimension"
    location = var.region
    project = var.project
    description = "Cloud function to create the users dimension in BigQuery"

    build_config {
        runtime = "python312"
        entry_point = "main"

        source {
            storage_source {
                bucket = google_storage_bucket.cloud_functions_bucket.name
                object = google_storage_bucket_object.create_users_dimension_object.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory   = "1Gi"
        available_cpu      = "0.583"
        timeout_seconds = 400
        environment_variables = {
            PROJECT_ID = "${var.project}"
            DATASET_ID = google_bigquery_dataset.prep_songs_dimensions.dataset_id
            TABLE_ID = google_bigquery_table.dim_user.table_id
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudfunctions.googleapis.com"],
        google_bigquery_dataset.prep_songs_dimensions,
        google_bigquery_table.dim_user
    ]
}