resource "google_service_account" "service_account" {
    project = var.project
    account_id = "sa-engenharia-de-dados"
    display_name = "Service Account for Data Engineer"

    depends_on = [
        google_project_service.required_apis["iam.googleapis.com"]
    ]
}

resource "google_project_iam_member" "sa_roles_runner" {
    for_each = toset([
        "roles/cloudfunctions.invoker",
        "roles/run.invoker",
        "roles/workflows.invoker",
        "roles/logging.logWriter",
        "roles/secretmanager.secretAccessor"
    ])

    role = each.value
    member = "serviceAccount:${google_service_account.service_account.email}"
    project = var.project
}





resource "google_service_account" "cloud_functions_service_account" {
    project = var.project
    account_id = "cloud-functions-sa"
    display_name = "Service Account for the cloud functions to communicate with other resources"

    depends_on = [
        google_project_service.required_apis["iam.googleapis.com"]
    ]
}

resource "google_project_iam_member" "cloud_functions_service_account_roles" {
    for_each = toset([
        "roles/secretmanager.secretAccessor",
        "roles/bigquery.dataEditor",
        "roles/bigquery.jobUser",
        "roles/storage.admin",
        "roles/storage.objectAdmin"
    ])

    role = each.value
    member = "serviceAccount:${google_service_account.cloud_functions_service_account.email}"
    project = var.project
}