# Comprehensive Audit Logging Configuration
# Implements security monitoring and compliance requirements
# Enables Data Access logs for critical services

# Artifact Registry audit logging
resource "google_project_iam_audit_config" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  # Admin activity (who changed what configuration)
  audit_log_config {
    log_type = "ADMIN_READ"
  }

  # Data read (who pulled which images)
  audit_log_config {
    log_type = "DATA_READ"

    # Optional: Exempt specific service accounts from DATA_READ to reduce noise
    # exempted_members = [
    #   "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
    # ]
  }

  # Data write (who pushed which images)
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# IAM audit logging
resource "google_project_iam_audit_config" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  # Log service account key creation/deletion
  audit_log_config {
    log_type = "DATA_WRITE"
  }

  # Log IAM policy checks
  audit_log_config {
    log_type = "DATA_READ"
  }
}

# Cloud Storage audit logging
resource "google_project_iam_audit_config" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"

    # Exempt Cloud Build to reduce log volume
    exempted_members = [
      "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
    ]
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Notebooks (Workbench) audit logging
resource "google_project_iam_audit_config" "notebooks" {
  project = var.project_id
  service = "notebooks.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Cloud KMS audit logging
resource "google_project_iam_audit_config" "kms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Cloud Build audit logging
resource "google_project_iam_audit_config" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# BigQuery dataset for long-term audit log storage
resource "google_bigquery_dataset" "security_audit_logs" {
  dataset_id                  = "security_audit_logs"
  friendly_name               = "Security Audit Logs"
  description                 = "Audit logs for security monitoring, compliance, and incident investigation"
  location                    = "EU"        # Adjust based on data residency requirements
  default_table_expiration_ms = 63072000000 # 2 years (730 days)

  labels = {
    environment = "production"
    managed-by  = "terraform"
    purpose     = "security-audit"
    compliance  = "required"
  }

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  # Grant security team access
  access {
    role          = "roles/bigquery.dataViewer"
    special_group = "projectViewers"
  }
}

# Log sink to export audit logs to BigQuery
resource "google_logging_project_sink" "security_audit_sink" {
  name        = "security-audit-sink"
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.security_audit_logs.dataset_id}"

  # Filter for security-relevant logs
  filter = <<-EOT
    (
      protoPayload.serviceName="artifactregistry.googleapis.com" OR
      protoPayload.serviceName="iam.googleapis.com" OR
      protoPayload.serviceName="storage.googleapis.com" OR
      protoPayload.serviceName="notebooks.googleapis.com" OR
      protoPayload.serviceName="cloudkms.googleapis.com" OR
      protoPayload.serviceName="cloudbuild.googleapis.com"
    )
    AND (
      protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"
    )
    AND NOT (
      protoPayload.methodName=~"^storage\\.objects\\.(get|list)$" AND
      protoPayload.authenticationInfo.principalEmail=~"@cloudbuild.gserviceaccount.com$"
    )
  EOT

  unique_writer_identity = true

  bigquery_options {
    use_partitioned_tables = true
  }

  depends_on = [
    google_bigquery_dataset.security_audit_logs
  ]
}

# Grant the log sink permission to write to BigQuery
resource "google_bigquery_dataset_iam_member" "sink_writer" {
  dataset_id = google_bigquery_dataset.security_audit_logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.security_audit_sink.writer_identity
}

# Optional: Alert policy for suspicious activity
resource "google_monitoring_alert_policy" "security_alerts" {
  display_name = "WBI Security Audit Alerts"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Service Account Key Created"

    condition_matched_log {
      filter = <<-EOT
        protoPayload.serviceName="iam.googleapis.com"
        AND protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"
        AND severity="NOTICE"
      EOT

      label_extractors = {
        "service_account" = "EXTRACT(protoPayload.request.name)"
      }
    }
  }

  conditions {
    display_name = "IAM Policy Modified"

    condition_matched_log {
      filter = <<-EOT
        protoPayload.serviceName="iam.googleapis.com"
        AND protoPayload.methodName="SetIamPolicy"
        AND severity="NOTICE"
      EOT
    }
  }

  notification_channels = [] # Add notification channels as needed

  alert_strategy {
    auto_close = "604800s" # 7 days
  }

  documentation {
    content   = "Security alert: Potentially sensitive IAM operation detected. Review audit logs in BigQuery dataset: security_audit_logs"
    mime_type = "text/markdown"
  }
}

# Outputs
output "audit_log_dataset" {
  description = "BigQuery dataset for audit logs"
  value       = google_bigquery_dataset.security_audit_logs.dataset_id
}

output "audit_log_sink" {
  description = "Log sink name for audit logs"
  value       = google_logging_project_sink.security_audit_sink.name
}

output "audit_services_enabled" {
  description = "Services with audit logging enabled"
  value = [
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "notebooks.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}
