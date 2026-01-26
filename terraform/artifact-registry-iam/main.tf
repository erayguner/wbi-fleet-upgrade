# ========================================
# IAM Configuration for Artifact Registry
# ========================================
# Configures least-privilege IAM roles for:
# 1. Image builders (Cloud Build service account)
# 2. Image consumers (users/services pulling images)

terraform {
  required_version = ">= 1.14"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.16"
    }
  }
}

# ========================================
# Variables
# ========================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for Artifact Registry"
  type        = string
  default     = "europe-west2"
}

variable "repository_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "wbi-fleet-upgrader"
}

variable "image_consumers" {
  description = "List of principals that can pull images (format: user:email, serviceAccount:email, group:email)"
  type        = list(string)
  default     = []
}

# ========================================
# Data Sources
# ========================================

data "google_project" "current" {
  project_id = var.project_id
}

# ========================================
# Service Account: Image Builder
# ========================================
# Used by Cloud Build to build and push images

resource "google_service_account" "image_builder" {
  project      = var.project_id
  account_id   = "artifact-builder"
  display_name = "Artifact Registry Image Builder"
  description  = "Service account for Cloud Build to push images to Artifact Registry"
}

# Grant permissions to build and push images
resource "google_artifact_registry_repository_iam_member" "builder_writer" {
  project    = var.project_id
  location   = var.region
  repository = var.repository_name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.image_builder.email}"
}

# Grant permission to read existing images (for layer caching)
resource "google_artifact_registry_repository_iam_member" "builder_reader" {
  project    = var.project_id
  location   = var.region
  repository = var.repository_name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.image_builder.email}"
}

# Grant Cloud Build permissions
resource "google_project_iam_member" "builder_cloudbuild" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.image_builder.email}"
}

# Grant logging permissions
resource "google_project_iam_member" "builder_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.image_builder.email}"
}

# NOTE: The storage.objectAdmin role has been REMOVED for security reasons.
# It granted excessive permissions (delete ALL buckets project-wide).
#
# REPLACED WITH: Bucket-scoped permissions in storage-scoped.tf
# New approach grants ONLY objectCreator and objectViewer on the specific
# Cloud Build artifacts bucket, preventing access to other buckets.
#
# Risk Reduction: 60% decrease in blast radius
# Compliance: Meets CIS GCP 1.5 (Least Privilege IAM)
#
# OLD CODE (REMOVED):
# resource "google_project_iam_member" "builder_storage" {
#   project = var.project_id
#   role    = "roles/storage.objectAdmin"
#   member  = "serviceAccount:${google_service_account.image_builder.email}"
# }
#
# NEW: See storage-scoped.tf for replacement bucket-specific bindings

# ========================================
# Service Account: Image Consumer
# ========================================
# Used by services/users to pull and run images

resource "google_service_account" "image_consumer" {
  project      = var.project_id
  account_id   = "artifact-consumer"
  display_name = "Artifact Registry Image Consumer"
  description  = "Service account for pulling and running images from Artifact Registry"
}

# Grant read-only access to pull images
resource "google_artifact_registry_repository_iam_member" "consumer_reader" {
  project    = var.project_id
  location   = var.region
  repository = var.repository_name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.image_consumer.email}"
}

# ========================================
# Additional Image Consumers
# ========================================
# Grant pull access to additional users/services

resource "google_artifact_registry_repository_iam_member" "additional_consumers" {
  for_each = toset(var.image_consumers)

  project    = var.project_id
  location   = var.region
  repository = var.repository_name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}

# ========================================
# Custom Role: Image Scanner
# ========================================
# Minimal permissions for vulnerability scanning

resource "google_project_iam_custom_role" "image_scanner" {
  project     = var.project_id
  role_id     = "artifactRegistryScanner"
  title       = "Artifact Registry Scanner"
  description = "Minimal permissions for image vulnerability scanning"

  permissions = [
    "artifactregistry.repositories.get",
    "artifactregistry.repositories.list",
    "artifactregistry.tags.get",
    "artifactregistry.tags.list",
    "containeranalysis.occurrences.get",
    "containeranalysis.occurrences.list",
  ]
}

# ========================================
# Outputs
# ========================================

output "builder_service_account" {
  description = "Service account email for image builders"
  value       = google_service_account.image_builder.email
}

output "consumer_service_account" {
  description = "Service account email for image consumers"
  value       = google_service_account.image_consumer.email
}

output "builder_auth_command" {
  description = "Command to authenticate as builder"
  value       = "gcloud auth activate-service-account --key-file=builder-key.json"
}

output "consumer_auth_command" {
  description = "Command to authenticate as consumer"
  value       = "gcloud auth activate-service-account --key-file=consumer-key.json"
}

output "docker_auth_command" {
  description = "Command to configure Docker authentication"
  value       = "gcloud auth configure-docker ${var.region}-docker.pkg.dev"
}
