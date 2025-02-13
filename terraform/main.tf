resource "google_service_account" "gcp_sa" {
    project = var.project
    account_id = "sa-engenharia-de-dados"
    display_name = "Service Account for Data Engineer"
}

resource "google_project_iam_member" "sa_roles_runner" {
    for_each = toset([
        "roles/cloudfunctions.invoker",
        "roles/run.invoker",
        "roles/workflows.invoker",
        "roles/logging.logWriter"
    ])
    role = each.value
    member = "serviceAccount:${google_service_account.gcp_sa.email}"
    project = var.project
}

# Activate APIs
# resource "google_project_service" "required_apis" {
#     for_each = toset([
#         "cloudresourcemanager.googleapis.com",
#         "cloudfunctions.googleapis.com",
#         "monitoring.googleapis.com",
#         "iam.googleapis.com",
#         "iamcredentials.googleapis.com",
#         "logging.googleapis.com",
#         "storage.googleapis.com",
#         "run.googleapis.com",
#     ])
#     project = var.project
#     service = each.key
#     disable_on_destroy         = false
#     disable_dependent_services = true
# }

# module "required_apis" {
#     source = "terraform-google-modules/project-factory/google"
#     version = "~> 18.0"
#     project_id = var.project
#     activate_apis = [
#         "cloudresourcemanager.googleapis.com",
#         "iam.googleapis.com",
#         "iamcredentials.googleapis.com",
#         "logging.googleapis.com",
#         "monitoring.googleapis.com",
#         "storage.googleapis.com",
#         "run.googleapis.com",
#         "cloudfunctions.googleapis.com",
#     ]
#     disable_services_on_destroy = false
# }

# resource "google_project_iam_member" "sa_roles_runner" {
#     for_each = [
#         "roles/logging.configWriter",
#         "roles/logging.logWriter",
#         "roles/serviceusage.serviceUsageAdmin",
#         "roles/storage.admin",
#         "roles/cloudkms.admin",
#         "roles/iam.serviceAccountAdmin",
#         "roles/compute.viewer",
#         "roles/iam.serviceAccountKeyAdmin",
#         "roles/iam.workloadIdentityPoolAdmin",
#         "roles/iam.roleAdmin",
#         "roles/pubsub.admin",
#         "roles/cloudfunctions.admin",
#         "roles/iam.serviceAccountUser",
#         "roles/cloudbuild.builds.builder",
#         "roles/pubsub.publisher",
#         "roles/eventarc.eventReceiver",
#         "roles/run.invoker",
#     ]
#     role = each.value
#     member = "serviceAccount:${var.service_account_email}"
#     project = var.project
# }



resource "google_storage_bucket" "cloud_functions_bucket" {
    name = "cloud-functions-${var.project}"
    location = var.region
    force_destroy = true
    uniform_bucket_level_access = true
}

data "archive_file" "cloud_function_code" {
    type = "zip"
    source_dir = "${path.module}/../cf_extract"
    output_path = "${path.module}/deploy/cf_extract.zip"
}

resource "google_storage_bucket_object" "zip" {
    source = data.archive_file.cloud_function_code.output_path
    content_type = "application/zip"
    name = "extract.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.cloud_function_code
    ]
}

# data "google_storage_project_service_account" "gcs_account" {
#     project = var.project
# }

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
                object = google_storage_bucket_object.zip.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory = "256M"
        timeout_seconds = 60
        environment_variables = {
            SPOTIFY_CLIENT_ID = var.spotify_client_id
            SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
        }
    }
}

data "archive_file" "transform_cloud_function_code" {
    type = "zip"
    source_dir = "${path.module}/../cf_transform"
    output_path = "${path.module}/deploy/cf_transform.zip"
}

resource "google_storage_bucket_object" "transform_zip" {
    source = data.archive_file.transform_cloud_function_code.output_path
    content_type = "application/zip"
    name = "transform.zip"
    bucket = google_storage_bucket.cloud_functions_bucket.name
    depends_on = [
        google_storage_bucket.cloud_functions_bucket,
        data.archive_file.transform_cloud_function_code
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
                object = google_storage_bucket_object.transform_zip.name
            }
        }
    }

    service_config {
        max_instance_count = 1
        available_memory   = "1Gi"
        available_cpu      = "0.583"
        timeout_seconds = 60
        environment_variables = {
            GCP_PROJECT_ID = var.project
        }
    }
}

# resource "google_cloudfunctions2_function_iam_member" "invoker" {
#     project        = var.project
#     location       = var.region
#     cloud_function = google_cloudfunctions2_function.function.name
#     role           = "roles/cloudfunctions.invoker"
#     member         = "serviceAccount:${google_service_account.gcp_sa.email}"
# }

# resource "google_cloud_run_service_iam_member" "cloud_run_invoker" {
#     project  = var.function.project
#     location = var.function.region
#     service  = google_cloudfunctions2_function.function.name
#     role     = "roles/run.invoker"
#     member   = "serviceAccount:${google_service_account.gcp_sa.email}"
# }

resource "google_workflows_workflow" "spotify_etl_workflow" {
    name     = "spotify-etl"
    project  = var.project
    region   = var.region

    description = "Workflow for the Spotify ETL process"

    service_account = google_service_account.gcp_sa.email

    source_contents = <<-EOT
    main:
        params: [input]
        steps:
        - extract:
            call: http.post
            args:
                url: "${google_cloudfunctions2_function.extract_cloud_function.service_config[0].uri}"
                auth:
                    type: OIDC
            result: extract_response
        - logExtractResponse:
            call: sys.log
            args:
                text: "$(extract_response.body)"
        - transform:
            call: http.post
            args:
                url: "${google_cloudfunctions2_function.transform_cloud_function.service_config[0].uri}"
                auth:
                    type: OIDC
            result: transform_response
        - logTransformResponse:
            call: sys.log
            args:
                text: "$(transform_response.body)"
    EOT

    deletion_protection = false
}

resource "google_cloud_scheduler_job" "invoke_cloud_function" {
    name        = "spotify-etl"
    description = "Schedule the HTTPS trigger for the Spotify ETL Workflows"
    schedule    = "0 0 * * *"
    time_zone   = "America/Sao_Paulo"
    project     = var.project
    region      = var.region

    http_target {
        uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project}/locations/${var.region}/workflows/${google_workflows_workflow.spotify_etl_workflow.name}/executions"
        http_method = "POST"
        oauth_token {
            service_account_email = google_service_account.gcp_sa.email
        }
    }
}