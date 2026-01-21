# Terraform Configuration for WBI Cloud Build Service Account
#
# This module creates a dedicated service account with least-privilege
# IAM bindings for Cloud Build to run WBI upgrade/rollback operations.
#
# Usage:
#   cd terraform/cloudbuild-iam
#   terraform init
#   terraform plan -var="project_id=YOUR_PROJECT_ID"
#   terraform apply -var="project_id=YOUR_PROJECT_ID"

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

# Service Account for Cloud Build WBI operations
resource "google_service_account" "wbi_cloudbuild" {
  project      = var.project_id
  account_id   = "wbi-cloudbuild"
  display_name = "WBI Cloud Build Service Account"
  description  = "Dedicated service account for Vertex AI Workbench upgrade/rollback operations via Cloud Build"
}

# IAM Bindings - Least Privilege Roles

# Role: Notebooks Admin - Required for manage Workbench instances
resource "google_project_iam_member" "notebooks_admin" {
  project = var.project_id
  role    = "roles/notebooks.admin"
  member  = "serviceAccount:${google_service_account.wbi_cloudbuild.email}"
}

# Role: Logging Log Writer - Required for structured logging
resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wbi_cloudbuild.email}"
}

# Role: Storage Object Creator - Required for uploading reports to GCS
resource "google_project_iam_member" "storage_object_creator" {
  count   = var.enable_artifact_storage ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.wbi_cloudbuild.email}"
}

# Role: Service Account User - Required for Cloud Build to use this SA
resource "google_service_account_iam_member" "cloudbuild_sa_user" {
  service_account_id = google_service_account.wbi_cloudbuild.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

# Optional: Grant the default Cloud Build SA permission to use this SA
resource "google_project_iam_member" "cloudbuild_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

# Optional: Create a GCS bucket for build artifacts
resource "google_storage_bucket" "cloudbuild_artifacts" {
  count    = var.create_artifact_bucket ? 1 : 0
  project  = var.project_id
  name     = "${var.project_id}-cloudbuild-artifacts"
  location = var.bucket_location

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = var.artifact_retention_days
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    purpose = "cloudbuild-artifacts"
    managed = "terraform"
  }
}
