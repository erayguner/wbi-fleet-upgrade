# Variables for WBI Cloud Build IAM Configuration

variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string
}

variable "project_number" {
  description = "GCP project number (required for Cloud Build SA binding). Get with: gcloud projects describe PROJECT_ID --format='value(projectNumber)'"
  type        = string
}

variable "enable_artifact_storage" {
  description = "Enable Storage Object Creator role for uploading reports to GCS"
  type        = bool
  default     = true
}

variable "create_artifact_bucket" {
  description = "Create a GCS bucket for Cloud Build artifacts"
  type        = bool
  default     = false
}

variable "bucket_location" {
  description = "Location for the artifact bucket (if created)"
  type        = string
  default     = "EU"
}

variable "artifact_retention_days" {
  description = "Number of days to retain artifacts in the bucket"
  type        = number
  default     = 30
}
