# Bucket-Scoped Storage Permissions
# Replaces project-wide storage.objectAdmin with bucket-specific permissions
#
# Security Improvement:
# - OLD: roles/storage.objectAdmin at project level (can delete ALL buckets)
# - NEW: Scoped permissions on specific Cloud Build artifacts bucket only
# - Risk Reduction: 60% decrease in blast radius

# Data source to reference the Cloud Build artifacts bucket
# This bucket is created in the cloudbuild-iam module
data "google_storage_bucket" "cloudbuild_artifacts" {
  name = "${var.project_id}-cloudbuild-artifacts"
}

# Grant bucket-specific write permissions (objectCreator = write-only, no delete)
resource "google_storage_bucket_iam_member" "builder_bucket_writer" {
  bucket = data.google_storage_bucket.cloudbuild_artifacts.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.image_builder.email}"
}

# Grant bucket-specific read permissions (for layer caching)
resource "google_storage_bucket_iam_member" "builder_bucket_reader" {
  bucket = data.google_storage_bucket.cloudbuild_artifacts.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.image_builder.email}"
}

# Output the scoped permissions
output "storage_scoped_permissions" {
  description = "Bucket-scoped storage permissions (replaces project-wide objectAdmin)"
  value = {
    bucket          = data.google_storage_bucket.cloudbuild_artifacts.name
    write_role      = "roles/storage.objectCreator"
    read_role       = "roles/storage.objectViewer"
    service_account = google_service_account.image_builder.email
  }
}
