resource "google_cloud_scheduler_job" "invoke_cloud_function" {
    name        = "songs-etl"
    description = "Schedule the HTTPS trigger for the songs ETL Workflows"
    schedule    = "0 0 * * *"
    time_zone   = "America/Sao_Paulo"
    project     = var.project
    region      = var.region

    http_target {
        uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project}/locations/${var.region}/workflows/${google_workflows_workflow.songs_etl_workflow.name}/executions"
        http_method = "POST"
        oauth_token {
            service_account_email = google_service_account.service_account.email
        }
    }

    depends_on = [
        google_project_service.required_apis["cloudscheduler.googleapis.com"],
        google_workflows_workflow.songs_etl_workflow,
        google_service_account.service_account  
    ]
}