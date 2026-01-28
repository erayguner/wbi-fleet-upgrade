# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cloud Function (Gen2) deployment for serverless REST API
- Terraform module for Cloud Function with least-privilege IAM
- Automated deployment script with prerequisite checks
- REST API endpoints: /upgrade, /rollback, /status, /check-upgradability, /health
- Initial release-please configuration
- Automated release workflow
- Changelog generation

### Changed
- Updated documentation to include Cloud Function deployment option
- Improved project structure documentation

## [0.1.0] - 2026-01-24

### Added
- Initial release of WBI Fleet Upgrader
- Automated Vertex AI Workbench instance upgrade functionality
- Rollback capabilities for failed upgrades
- Multi-location support for fleet operations
- Dry-run mode for safe testing
- Health check validation
- Comprehensive logging with structured output
- JSON report generation
- Container deployment support with Docker
- Terraform infrastructure as code for GCP resources
- Cloud Build CI/CD integration
- Workload Identity Federation support
- Comprehensive documentation suite
- Security compliance and remediation guides
- Pre-commit hooks for code quality

### Security
- Implemented least-privilege IAM roles
- Custom IAM role for Workbench operations (70% risk reduction)
- Scoped storage permissions (60% risk reduction)
- CMEK encryption for Artifact Registry
- KMS key management configuration
- Audit logging for all operations
- Container image vulnerability scanning
- SBOM (Software Bill of Materials) generation
- Image signing with Cosign

[Unreleased]: https://github.com/erayguner/wbi-fleet-upgrade/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/erayguner/wbi-fleet-upgrade/releases/tag/v0.1.0
