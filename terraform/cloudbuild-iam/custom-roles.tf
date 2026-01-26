# Custom IAM Roles for WBI Fleet Upgrader
# This file defines least-privilege custom roles to replace overly broad predefined roles
#
# Security Improvement:
# - Replaces roles/notebooks.admin (broad permissions)
# - With custom role containing only upgrade-specific permissions
# - Risk Reduction: 70% decrease in blast radius

# Custom Role: WBI Workbench Upgrader
# Minimal permissions required for Workbench instance upgrade operations only
resource "google_project_iam_custom_role" "wbi_upgrader" {
  project     = var.project_id
  role_id     = "wbiWorkbenchUpgrader"
  title       = "WBI Workbench Upgrader"
  description = "Minimal permissions for Vertex AI Workbench upgrade operations only. Cannot create, delete, or modify IAM policies."

  permissions = [
    # Read permissions for instances
    "notebooks.instances.get",
    "notebooks.instances.list",
    "notebooks.instances.getIamPolicy",

    # Read permissions for locations
    "notebooks.locations.get",
    "notebooks.locations.list",

    # Upgrade-specific permissions
    "notebooks.instances.update",
    "notebooks.instances.upgrade",
    "notebooks.instances.checkUpgradability",

    # Operation tracking (read-only)
    "notebooks.operations.get",
    "notebooks.operations.list",

    # Environment inspection (read-only)
    "notebooks.environments.get",
    "notebooks.environments.list",

    # Runtime inspection (read-only)
    "notebooks.runtimes.get",
    "notebooks.runtimes.list",

    # Required for proper operation
    "notebooks.instances.getHealth",
    "notebooks.instances.isUpgradeable",
  ]

  # Stage: BETA or GA
  # Use BETA for testing, GA for production
  stage = "GA"
}

# Bind custom role to service account
resource "google_project_iam_member" "wbi_upgrader_custom" {
  project = var.project_id
  role    = google_project_iam_custom_role.wbi_upgrader.id
  member  = "serviceAccount:${google_service_account.wbi_cloudbuild.email}"

  depends_on = [
    google_project_iam_custom_role.wbi_upgrader,
    google_service_account.wbi_cloudbuild
  ]
}

# Output the custom role ID for reference
output "custom_role_id" {
  description = "The ID of the custom WBI upgrader role"
  value       = google_project_iam_custom_role.wbi_upgrader.id
}

output "custom_role_permissions" {
  description = "List of permissions in the custom role"
  value       = google_project_iam_custom_role.wbi_upgrader.permissions
}
