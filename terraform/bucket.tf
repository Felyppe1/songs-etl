
resource "google_storage_bucket" "landing_bucket" {
    name = "landing-${var.project}"
    location = var.region
    force_destroy = true
    uniform_bucket_level_access = true

    depends_on = [
        google_project_service.required_apis["storage.googleapis.com"]
    ]
}

resource "google_storage_bucket" "cloud_functions_bucket" {
    name = "cloud-functions-${var.project}"
    location = var.region
    force_destroy = true
    uniform_bucket_level_access = true

    depends_on = [
        google_project_service.required_apis["storage.googleapis.com"]
    ]
}