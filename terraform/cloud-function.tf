data "archive_file" "extract_function_zip" {
    type = "zip"
    source_dir = "${path.module}/../cf_extract"
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






data "archive_file" "transform_function_zip" {
    type = "zip"
    source_dir = "${path.module}/../cf_transform"
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