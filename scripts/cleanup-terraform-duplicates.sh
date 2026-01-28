#!/bin/bash
# Cleanup duplicate Terraform files that need to be merged

cd /Users/eray/wbi-fleet-upgrade || exit 1

echo "🧹 Cleaning up Terraform duplicate files..."
echo ""

# Remove files that should be merged, not added
if [ -f "terraform/artifact-registry/main-updated.tf" ]; then
	echo "  ❌ Removing: terraform/artifact-registry/main-updated.tf"
	echo "     → Merge changes into main.tf instead"
	rm terraform/artifact-registry/main-updated.tf
fi

if [ -f "terraform/cloudbuild-iam/storage-bucket-updated.tf" ]; then
	echo "  ❌ Removing: terraform/cloudbuild-iam/storage-bucket-updated.tf"
	echo "     → Merge changes into main.tf instead"
	rm terraform/cloudbuild-iam/storage-bucket-updated.tf
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Files kept (ready to use):"
echo "  ✅ terraform/cloudbuild-iam/custom-roles.tf"
echo "  ✅ terraform/cloudbuild-iam/audit-logging.tf"
echo "  ✅ terraform/cloudbuild-iam/workload-identity.tf"
echo "  ✅ terraform/artifact-registry/kms.tf"
echo "  ✅ terraform/artifact-registry-iam/storage-scoped.tf"
echo ""
echo "Next: See docs/TERRAFORM_INTEGRATION_GUIDE.md for merge instructions"
