resource "google_secret_manager_secret" "songs" {
    secret_id = "songs"
    replication {
        auto {}
    }

    depends_on = [
        google_project_service.required_apis["secretmanager.googleapis.com"]
    ]
}