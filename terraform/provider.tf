provider "google" {
    credentials = file(var.service_key)
    project = var.project
    region = var.region
}