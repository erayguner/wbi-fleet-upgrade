# Workload Identity Federation for WBI Fleet Upgrader
# Eliminates need for service account keys (more secure)
# Supports: Cloud Build, GKE, GitHub Actions, GitLab CI

# =============================================================================
# Cloud Build Workload Identity (Built-in)
# =============================================================================

# Cloud Build automatically uses Workload Identity with its service account
# No additional configuration needed - it's the default secure method

# Grant Cloud Build SA the ability to impersonate our custom SA
resource "google_service_account_iam_member" "cloudbuild_workload_identity" {
  service_account_id = google_service_account.wbi_cloudbuild.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/cloud-build]"
}

# =============================================================================
# GKE Workload Identity
# =============================================================================

# Kubernetes Service Account for WBI Fleet Upgrader
resource "google_service_account" "wbi_k8s" {
  account_id   = "wbi-fleet-upgrader-k8s"
  display_name = "WBI Fleet Upgrader - GKE Workload Identity"
  description  = "Service account for WBI Fleet Upgrader running in GKE (Workload Identity)"
}

# Grant Kubernetes SA permission to impersonate GCP SA
resource "google_service_account_iam_member" "k8s_workload_identity" {
  service_account_id = google_service_account.wbi_k8s.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}

# Grant necessary permissions to K8s SA
resource "google_project_iam_member" "k8s_wbi_upgrader" {
  project = var.project_id
  role    = google_project_iam_custom_role.wbi_upgrader.id
  member  = "serviceAccount:${google_service_account.wbi_k8s.email}"
}

resource "google_project_iam_member" "k8s_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.wbi_k8s.email}"
}

# =============================================================================
# GitHub Actions Workload Identity Federation
# =============================================================================

# Create Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
  disabled                  = false
}

# Create Workload Identity Provider for GitHub
resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions Provider"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_org}'"
}

# Service Account for GitHub Actions
resource "google_service_account" "github_actions" {
  account_id   = "wbi-github-actions"
  display_name = "WBI Fleet Upgrader - GitHub Actions"
  description  = "Service account for GitHub Actions CI/CD (Workload Identity)"
}

# Grant GitHub Actions permission to impersonate SA
resource "google_service_account_iam_member" "github_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# Grant GitHub Actions necessary permissions
resource "google_project_iam_member" "github_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_cloudbuild_builds_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# =============================================================================
# GitLab CI Workload Identity Federation (Optional)
# =============================================================================

# Create Workload Identity Pool for GitLab CI
resource "google_iam_workload_identity_pool" "gitlab_ci" {
  count                     = var.enable_gitlab_wif ? 1 : 0
  workload_identity_pool_id = "gitlab-ci-pool"
  display_name              = "GitLab CI Pool"
  description               = "Workload Identity Pool for GitLab CI/CD"
  disabled                  = false
}

# Create Workload Identity Provider for GitLab
resource "google_iam_workload_identity_pool_provider" "gitlab_ci" {
  count                              = var.enable_gitlab_wif ? 1 : 0
  workload_identity_pool_id          = google_iam_workload_identity_pool.gitlab_ci[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "gitlab-ci-provider"
  display_name                       = "GitLab CI Provider"
  description                        = "OIDC provider for GitLab CI"

  attribute_mapping = {
    "google.subject"           = "assertion.sub"
    "attribute.project_path"   = "assertion.project_path"
    "attribute.namespace_path" = "assertion.namespace_path"
    "attribute.ref"            = "assertion.ref"
    "attribute.ref_type"       = "assertion.ref_type"
  }

  oidc {
    issuer_uri = "https://gitlab.com"
  }

  attribute_condition = "assertion.namespace_path == '${var.gitlab_namespace}'"
}

# Service Account for GitLab CI
resource "google_service_account" "gitlab_ci" {
  count        = var.enable_gitlab_wif ? 1 : 0
  account_id   = "wbi-gitlab-ci"
  display_name = "WBI Fleet Upgrader - GitLab CI"
  description  = "Service account for GitLab CI/CD (Workload Identity)"
}

resource "google_service_account_iam_member" "gitlab_workload_identity" {
  count              = var.enable_gitlab_wif ? 1 : 0
  service_account_id = google_service_account.gitlab_ci[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gitlab_ci[0].name}/attribute.namespace_path/${var.gitlab_namespace}"
}

# =============================================================================
# Variables
# =============================================================================

variable "k8s_namespace" {
  description = "Kubernetes namespace for WBI Fleet Upgrader"
  type        = string
  default     = "default"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name"
  type        = string
  default     = "wbi-fleet-upgrader"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "yourorg"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "wbi-fleet-upgrade"
}

variable "enable_gitlab_wif" {
  description = "Enable GitLab CI Workload Identity Federation"
  type        = bool
  default     = false
}

variable "gitlab_namespace" {
  description = "GitLab namespace (group or user)"
  type        = string
  default     = ""
}

# =============================================================================
# Outputs
# =============================================================================

output "github_actions_provider_name" {
  description = "GitHub Actions Workload Identity Provider name for use in workflows"
  value       = google_iam_workload_identity_pool_provider.github_actions.name
}

output "github_actions_service_account" {
  description = "GitHub Actions service account email"
  value       = google_service_account.github_actions.email
}

output "k8s_service_account_email" {
  description = "GKE service account email"
  value       = google_service_account.wbi_k8s.email
}

output "workload_identity_setup_complete" {
  description = "Workload Identity Federation setup status"
  value       = "✅ WIF configured for: Cloud Build (native), GKE, GitHub Actions${var.enable_gitlab_wif ? ", GitLab CI" : ""}"
}
