# Outputs for WBI Cloud Build IAM Configuration
output "service_account_email" {
  description = "Email of the WBI Cloud Build service account"
  value       = google_service_account.wbi_cloudbuild.email
}

output "service_account_name" {
  description = "Full resource name of the service account"
  value       = google_service_account.wbi_cloudbuild.name
}

output "service_account_id" {
  description = "Unique ID of the service account"
  value       = google_service_account.wbi_cloudbuild.unique_id
}

output "artifact_bucket_name" {
  description = "Name of the Cloud Build artifacts bucket (if created)"
  value       = var.create_artifact_bucket ? google_storage_bucket.cloudbuild_artifacts[0].name : null
}

output "cloudbuild_yaml_service_account_line" {
  description = "The serviceAccount line to use in cloudbuild.yaml"
  value       = "serviceAccount: 'projects/${var.project_id}/serviceAccounts/${google_service_account.wbi_cloudbuild.email}'"
}
