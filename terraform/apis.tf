resource "google_project_service" "required_apis" {
    for_each = toset([
        "secretmanager.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "cloudfunctions.googleapis.com",
        "cloudscheduler.googleapis.com",
        "monitoring.googleapis.com",
        "iam.googleapis.com",
        "iamcredentials.googleapis.com",
        "logging.googleapis.com",
        "storage.googleapis.com",
        "run.googleapis.com",
        "workflowexecutions.googleapis.com",
        "cloudbuild.googleapis.com",
        "artifactregistry.googleapis.com"
    ])

    project = var.project
    service = each.value

    disable_on_destroy         = false
}