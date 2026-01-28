# WBI Fleet Upgrader - Documentation Index

Complete documentation for the Vertex AI Workbench Fleet Upgrader tool.

---

## 🚀 Getting Started

Start here if you're new to the project:

### Quick Start Guides
- **[Main Quick Start](../QUICKSTART.md)** - Get started in 10 minutes with the Python tool
- **[Container Quick Start](CONTAINER_QUICKSTART.md)** - Get started with containerized deployment

### First-Time Setup
- **[Authentication Setup](AUTHENTICATION_SETUP.md)** - Configure GCP authentication (4 methods)
- **[Workload Identity Setup](WORKLOAD_IDENTITY_SETUP.md)** - Set up Workload Identity Federation (recommended)
- **[WIF Migration Checklist](WIF_MIGRATION_CHECKLIST.md)** - Migrate from service account keys to WIF

---

## 📋 Operations & Deployment

Production operations and deployment guides:

### Standard Operations
- **[Operations Guide](../OPERATIONS.md)** - Complete operational procedures and SOPs
- **[Upgrade & Rollback Guide](UPGRADE_ROLLBACK_GUIDE.md)** - Step-by-step upgrade and rollback procedures
- **[Troubleshooting Guide](../TROUBLESHOOTING.md)** - Common issues and solutions

### Container Deployment
- **[Container README](../CONTAINER_README.md)** - Container deployment overview
- **[Container Deployment Guide](CONTAINER_DEPLOYMENT.md)** - Complete container deployment guide
- **[Usage Examples](USAGE_EXAMPLES.md)** - Practical examples (local, CI/CD, K8s, Cloud Run)

### CI/CD Integration
- **[Cloud Build Setup](cloud-build.md)** - Google Cloud Build integration

### Cloud Function Deployment
- **[Cloud Function Deployment](CLOUD_FUNCTION_DEPLOYMENT.md)** - Deploy as serverless Cloud Function (Gen2)
- **[Cloud Function README](../cloud_function/README.md)** - Quick reference for Cloud Function API

---

## 🛡️ Security & Compliance

Security hardening and compliance documentation:

### Security Documentation
- **[Security Policy](../SECURITY.md)** - Project security policy and reporting procedures
- **[Security Compliance Report](SECURITY_COMPLIANCE_REPORT_2026.md)** - Comprehensive security audit (2026)
- **[Security Remediation Plan](SECURITY_REMEDIATION_PLAN.md)** - Detailed remediation roadmap
- **[Quick Wins Security](QUICK_WINS_SECURITY.md)** - Immediate security improvements (2-3 hours)

### Implementation Guides
- **[Implementation Guide](IMPLEMENTATION_GUIDE.md)** - Step-by-step security implementation

---

## 🏗️ Infrastructure & Terraform

Terraform infrastructure setup and configuration:

### Terraform Documentation
- **[Terraform Version Update](TERRAFORM_VERSION_UPDATE.md)** - Latest version update report
  - Terraform Core: 1.14.0
  - Google Provider: 7.16.0
  - Status: ✅ Complete

### Terraform Modules
Located in `../terraform/`:

#### 1. Cloud Build IAM (`cloudbuild-iam/`)
Service account and IAM configuration for Cloud Build operations:
- **main.tf** - Core IAM configuration with least-privilege roles
- **custom-roles.tf** - Custom IAM role for Workbench upgrades (70% risk reduction)
- **audit-logging.tf** - Comprehensive audit logging configuration
- **workload-identity.tf** - Workload Identity Federation setup
- **variables.tf** - Module variables
- **outputs.tf** - Module outputs

#### 2. Artifact Registry (`artifact-registry/`)
Docker image registry configuration:
- **main.tf** - Repository setup with cleanup policies
- **kms.tf** - Customer-managed encryption keys (CMEK)

#### 3. Artifact Registry IAM (`artifact-registry-iam/`)
IAM configuration for Artifact Registry:
- **main.tf** - Builder and consumer service accounts
- **storage-scoped.tf** - Scoped storage permissions (60% risk reduction)
- **least-privilege-roles.md** - Detailed IAM role documentation

#### 4. Cloud Function (`cloud-function/`)
Serverless Cloud Function deployment:
- **main.tf** - Cloud Function Gen2 with custom IAM role
- **deploy.sh** - Automated deployment script with prerequisite checks
- **terraform.tfvars.example** - Example configuration
- **IAM_LEAST_PRIVILEGE.md** - Least-privilege IAM documentation

---

## 🧪 Development & Contributing

For developers and contributors:

- **[Contributing Guide](../CONTRIBUTING.md)** - Development guidelines and testing procedures
- **[Main README](../README.md)** - Project overview and architecture

---

## 📊 Documentation Structure

```
wbi-fleet-upgrade/
├── README.md                    # Project overview
├── QUICKSTART.md               # Quick start guide
├── OPERATIONS.md               # Operations procedures
├── TROUBLESHOOTING.md          # Troubleshooting guide
├── SECURITY.md                 # Security policy
├── CONTRIBUTING.md             # Development guide
├── CONTAINER_README.md         # Container overview
├── CHANGELOG.md                # Version history
│
├── docs/                       # Complete documentation
│   ├── README.md              # This file
│   │
│   ├── Getting Started
│   │   ├── CONTAINER_QUICKSTART.md
│   │   ├── AUTHENTICATION_SETUP.md
│   │   ├── WORKLOAD_IDENTITY_SETUP.md
│   │   └── WIF_MIGRATION_CHECKLIST.md
│   │
│   ├── Operations
│   │   ├── CONTAINER_DEPLOYMENT.md
│   │   ├── CLOUD_FUNCTION_DEPLOYMENT.md
│   │   ├── UPGRADE_ROLLBACK_GUIDE.md
│   │   ├── USAGE_EXAMPLES.md
│   │   └── cloud-build.md
│   │
│   ├── Security
│   │   ├── SECURITY_COMPLIANCE_REPORT_2026.md
│   │   ├── SECURITY_REMEDIATION_PLAN.md
│   │   ├── QUICK_WINS_SECURITY.md
│   │   └── IMPLEMENTATION_GUIDE.md
│   │
│   └── Infrastructure
│       ├── TERRAFORM_VERSION_UPDATE.md
│       └── RELEASE_PROCESS.md
│
├── cloud_function/             # Serverless Cloud Function
│   ├── main.py                # HTTP entry point
│   ├── requirements.txt       # Dependencies
│   └── src/                   # Core modules
│
├── terraform/                  # Infrastructure as Code
│   ├── cloudbuild-iam/        # Cloud Build IAM
│   ├── artifact-registry/     # Docker registry
│   ├── artifact-registry-iam/ # Registry IAM
│   └── cloud-function/        # Cloud Function deployment
│
└── scripts/                    # Automation scripts
    ├── docker-entrypoint.sh
    ├── validate-phase1.sh
    ├── validate-terraform.sh
    └── verify-image.sh
```

---

## 🎯 Quick Reference

### By User Type

#### First-Time User
1. Read [Quick Start](../QUICKSTART.md)
2. Set up [Authentication](AUTHENTICATION_SETUP.md)
3. Try a dry-run
4. Review [Troubleshooting](../TROUBLESHOOTING.md) if needed

#### Operations Team
1. Review [Operations Guide](../OPERATIONS.md)
2. Understand [Upgrade & Rollback](UPGRADE_ROLLBACK_GUIDE.md)
3. Check [Usage Examples](USAGE_EXAMPLES.md)
4. Bookmark [Troubleshooting](../TROUBLESHOOTING.md)

#### DevOps/Platform Team
1. Review [Container Deployment](CONTAINER_DEPLOYMENT.md)
2. Set up [Cloud Build](cloud-build.md)
3. Configure [Workload Identity](WORKLOAD_IDENTITY_SETUP.md)
4. Review [Security Compliance](SECURITY_COMPLIANCE_REPORT_2026.md)

#### Security Team
1. Review [Security Policy](../SECURITY.md)
2. Read [Compliance Report](SECURITY_COMPLIANCE_REPORT_2026.md)
3. Check [Remediation Plan](SECURITY_REMEDIATION_PLAN.md)
4. Review [Quick Wins](QUICK_WINS_SECURITY.md)

---

## 📝 Document Status

| Document | Status | Last Updated | Accuracy |
|----------|--------|--------------|----------|
| Quick Start Guides | ✅ Current | 2026-01-21 | ✅ Verified |
| Operations Guides | ✅ Current | 2026-01-21 | ✅ Verified |
| Container Docs | ✅ Current | 2026-01-23 | ✅ Verified |
| Cloud Function Docs | ✅ Current | 2026-01-28 | ✅ Verified |
| Security Docs | ✅ Current | 2026-01-23 | ✅ Verified |
| Terraform Docs | ✅ Current | 2026-01-28 | ✅ Verified |
| Contributing Guide | ✅ Current | 2026-01-21 | ✅ Verified |

**Last Documentation Review:** 2026-01-28
**All documentation verified and up-to-date with current repository state.**

---

## 🔗 External Resources

- [Vertex AI Workbench Documentation](https://cloud.google.com/vertex-ai/docs/workbench)
- [Google Cloud IAM Best Practices](https://cloud.google.com/iam/docs/best-practices)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Cloud Build Documentation](https://cloud.google.com/build/docs)

---

**For questions or issues, see [Contributing Guide](../CONTRIBUTING.md) or [Security Policy](../SECURITY.md).**
