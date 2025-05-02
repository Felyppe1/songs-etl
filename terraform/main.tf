terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.8.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-project-songs"
    prefix = "terraform/state"
  }
}

provider "google" {
    project = var.project
    region = var.region
}
