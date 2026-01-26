# KMS Configuration for Customer-Managed Encryption Keys (CMEK)
# Implements CIS GCP 5.1 - Encryption at rest with customer-managed keys
# Implements PCI-DSS 3.4 - Cryptographic key management

# Key Ring for all WBI Fleet Upgrader encryption keys
resource "google_kms_key_ring" "main" {
  name     = "wbi-fleet-upgrader-keyring"
  location = var.region

  lifecycle {
    prevent_destroy = true
  }
}

# Encryption key for Artifact Registry
resource "google_kms_crypto_key" "artifact_registry" {
  name     = "artifact-registry-key"
  key_ring = google_kms_key_ring.main.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  # Rotate keys every 90 days (recommended for compliance)
  rotation_period = "7776000s" # 90 days in seconds

  labels = {
    environment = "production"
    managed-by  = "terraform"
    purpose     = "artifact-registry-encryption"
  }
}

# Encryption key for Cloud Storage buckets
resource "google_kms_crypto_key" "storage" {
  name     = "storage-key"
  key_ring = google_kms_key_ring.main.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  rotation_period = "7776000s" # 90 days

  labels = {
    environment = "production"
    managed-by  = "terraform"
    purpose     = "storage-encryption"
  }
}

# Signing key for Cosign image signatures
resource "google_kms_crypto_key" "cosign" {
  name     = "cosign-signing-key"
  key_ring = google_kms_key_ring.main.id
  purpose  = "ASYMMETRIC_SIGN"

  lifecycle {
    prevent_destroy = true
  }

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }

  labels = {
    environment = "production"
    managed-by  = "terraform"
    purpose     = "container-image-signing"
  }
}

# Grant Artifact Registry service account access to encryption key
resource "google_kms_crypto_key_iam_member" "artifact_registry_encrypter" {
  crypto_key_id = google_kms_crypto_key.artifact_registry.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
}

# Grant Cloud Storage service account access to encryption key
resource "google_kms_crypto_key_iam_member" "storage_encrypter" {
  crypto_key_id = google_kms_crypto_key.storage.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

# Grant Cloud Build service account access to Cosign signing key
resource "google_kms_crypto_key_iam_member" "cosign_signer" {
  crypto_key_id = google_kms_crypto_key.cosign.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

# Optional: Grant additional service account for local Cosign verification
resource "google_kms_crypto_key_iam_member" "cosign_verifier" {
  crypto_key_id = google_kms_crypto_key.cosign.id
  role          = "roles/cloudkms.publicKeyViewer"
  member        = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

# Outputs for use in other modules
output "kms_keyring_id" {
  description = "KMS Key Ring ID"
  value       = google_kms_key_ring.main.id
}

output "artifact_registry_kms_key_id" {
  description = "KMS key ID for Artifact Registry encryption"
  value       = google_kms_crypto_key.artifact_registry.id
}

output "storage_kms_key_id" {
  description = "KMS key ID for Cloud Storage encryption"
  value       = google_kms_crypto_key.storage.id
}

output "cosign_kms_key_id" {
  description = "KMS key ID for Cosign image signing"
  value       = google_kms_crypto_key.cosign.id
}

output "cosign_kms_key_version" {
  description = "Full KMS key path for Cosign (use in Cloud Build)"
  value       = "gcpkms://projects/${var.project_id}/locations/${var.region}/keyRings/${google_kms_key_ring.main.name}/cryptoKeys/${google_kms_crypto_key.cosign.name}"
}
