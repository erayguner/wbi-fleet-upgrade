# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the Vertex AI
Workbench Fleet Upgrader project.

## Workflows Overview

### 🔄 CI Pipeline (`ci.yml`)

**Triggers**: Push/PR to main/develop branches

Comprehensive continuous integration pipeline that runs:

- **Lint Job**: Code quality checks
  - Black formatting validation
  - Flake8 linting
  - Pylint code analysis
  - MyPy type checking

- **Test Job**: Multi-version testing
  - Tests on Python 3.11, 3.12, and 3.13
  - Pytest with coverage reporting
  - 80% minimum coverage threshold
  - Coverage reports uploaded to Codecov
  - HTML coverage reports as artifacts

- **Security Job**: Security scanning
  - pip-audit for dependency vulnerabilities
  - Gitleaks for secret detection

- **Build Job**: Package building
  - Builds Python wheel and source distribution
  - Uploads build artifacts

- **Integration Check Job**: End-to-end validation
  - Installs built package
  - Tests CLI functionality

### 🔒 CodeQL Analysis (`codeql.yml`)

**Triggers**: Push/PR to main/develop, weekly schedule (Mondays), manual

Advanced security analysis using GitHub CodeQL:

- Scans Python code for security vulnerabilities
- Runs `security-extended` and `security-and-quality` query suites
- Identifies potential security issues, bugs, and code quality problems
- Scheduled weekly scans to catch newly discovered vulnerabilities
- Results uploaded to GitHub Security tab

### ✨ Pre-commit Checks (`pre-commit.yml`)

**Triggers**: Push/PR to main/develop branches

Validates code against pre-commit hooks:

- Runs all pre-commit hooks defined in `.pre-commit-config.yaml`
- Includes: black, shfmt, gitleaks, yamllint, markdownlint
- Caches pre-commit environments for faster runs
- Comments on PR if checks fail

### 📦 Dependency Review (`dependency-review.yml`)

**Triggers**: Pull requests to main/develop

Reviews dependency changes in PRs:

- **Dependency Review Job**:
  - Checks for vulnerable dependencies
  - Validates licenses (MIT, Apache-2.0, BSD, ISC, Python-2.0)
  - Fails on critical severity vulnerabilities
  - Comments summary on PR

- **Dependency Scan Job**:
  - Runs pip-audit for vulnerability scanning
  - Runs Safety check for known security issues
  - Uploads detailed security reports as artifacts
  - Comments scan results on PR

### 🐚 Shell Script Validation (`shellcheck.yml`)

**Triggers**: Push/PR affecting .sh/.bash files

Validates bash scripts (wb-upgrade.sh, wb-rollback.sh):

- **ShellCheck Job**:
  - Lints shell scripts for common issues
  - Checks for best practices
  - Verifies scripts are executable

- **Syntax Check Job**:
  - Validates bash syntax
  - Runs shfmt for formatting validation

### 🚀 Release (`release.yml`)

**Triggers**: Tags matching v*.*.*, manual workflow dispatch

Automates release process:

- Builds Python package (wheel and sdist)
- Validates package with twine
- Creates GitHub Release with auto-generated notes
- Uploads distribution files to release
- Stores artifacts for 90 days

## Status Badges

Add these badges to your README.md:

```markdown
![CI](https://github.com/YOUR_ORG/wbi-fleet-upgrade/workflows/CI/badge.svg)
![CodeQL](https://github.com/YOUR_ORG/wbi-fleet-upgrade/workflows/CodeQL%20Security%20Analysis/badge.svg)
![Pre-commit](https://github.com/YOUR_ORG/wbi-fleet-upgrade/workflows/Pre-commit%20Checks/badge.svg)
[![codecov](https://codecov.io/gh/YOUR_ORG/wbi-fleet-upgrade/branch/main/graph/badge.svg)](https://codecov.io/gh/YOUR_ORG/wbi-fleet-upgrade)
```

## Required Secrets

Most workflows work out-of-the-box with `GITHUB_TOKEN`. Optional:

- `CODECOV_TOKEN`: For Codecov integration (recommended for private repos)

## Local Development

### Running Pre-commit Locally

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run on all files
pre-commit run --all-files
```

### Running Tests Locally

```bash
# Install dev dependencies
pip install -r requirements-dev.txt

# Run tests with coverage
pytest tests/ -v --cov=src --cov-report=html

# Open coverage report
open htmlcov/index.html
```

### Running Linters Locally

```bash
# Format with black
black .

# Lint with flake8
flake8 .

# Type check with mypy
mypy src/ main.py

# Lint with pylint
pylint src/ main.py
```

### Security Scanning Locally

```bash
# Install pip-audit
pip install pip-audit

# Scan for vulnerabilities
pip-audit
```

### Shell Script Validation Locally

```bash
# Install shellcheck (macOS)
brew install shellcheck

# Install shellcheck (Ubuntu/Debian)
apt-get install shellcheck

# Check scripts
shellcheck *.sh
```

## Workflow Maintenance

### Updating Python Version

To add support for new Python versions, update the matrix in `ci.yml`:

```yaml
matrix:
  python-version: ["3.11", "3.12", "3.13", "3.14"]  # Add new version
```

### Adjusting Coverage Threshold

Modify the `MIN_COVERAGE` environment variable in `ci.yml`:

```yaml
env:
  MIN_COVERAGE: 85  # Increase from 80
```

### Customizing CodeQL Queries

Edit the queries in `codeql.yml`:

```yaml
queries: security-extended,security-and-quality  # Modify query suites
```

## CI/CD Best Practices

1. **Always run workflows locally** before pushing
2. **Use `--dry-run`** when testing CLI changes
3. **Keep workflows fast** - use caching and matrix strategies
4. **Monitor workflow costs** - optimize runner usage
5. **Review security alerts** in the Security tab
6. **Update dependencies regularly** to get security fixes

## Troubleshooting

### Workflow Fails on Coverage

- Check if new code is covered by tests
- Review `htmlcov/` artifact for missing coverage
- Add tests to reach 80% threshold

### Pre-commit Hook Fails

- Run `pre-commit run --all-files` locally
- Commit the auto-fixed changes
- Push the updated code

### Dependency Vulnerabilities

- Review the security report in workflow artifacts
- Update vulnerable packages in `requirements.txt`
- Test thoroughly after updates

### ShellCheck Warnings

- Review ShellCheck output
- Fix issues or add `# shellcheck disable=SCXXXX` if intentional
- Ensure scripts remain executable (`chmod +x *.sh`)

## Contributing

When adding new workflows:

1. Test locally using `act` or GitHub CLI
2. Document the workflow in this README
3. Add appropriate status badges to main README
4. Ensure workflows follow security best practices
5. Use caching to optimize performance

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [CodeQL Documentation](https://codeql.github.com/docs/)
- [Pre-commit Documentation](https://pre-commit.com/)
- [pytest Documentation](https://docs.pytest.org/)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
