# ========================================
# Artifact Registry Setup
# ========================================
# Creates Artifact Registry repository for WBI Fleet Upgrader images
# Configures security scanning and retention policies

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

variable "description" {
  description = "Description of the repository"
  type        = string
  default     = "Container images for Vertex AI Workbench Fleet Upgrader"
}

# ========================================
# Artifact Registry Repository
# ========================================

resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_name
  description   = var.description
  format        = "DOCKER"

  # Cleanup policies to manage storage costs
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }

  labels = {
    managed_by  = "terraform"
    component   = "artifact-registry"
    environment = "production"
    application = "wbi-fleet-upgrader"
  }
}

# ========================================
# Enable Container Scanning
# ========================================

resource "google_project_service" "containerscanning" {
  project = var.project_id
  service = "containerscanning.googleapis.com"

  disable_on_destroy = false
}

# ========================================
# Outputs
# ========================================

output "repository_id" {
  description = "The ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.id
}

output "repository_name" {
  description = "The name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.name
}

output "repository_url" {
  description = "The URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_name}"
}

output "pull_command" {
  description = "Command to pull images from the repository"
  value       = "docker pull ${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_name}/wbi-fleet-upgrader:latest"
}
