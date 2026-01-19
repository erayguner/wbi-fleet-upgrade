# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the Vertex AI
Workbench Fleet Upgrader project.

## Workflows Overview

### 🔒 CodeQL Security Analysis (`codeql.yml`)

**Triggers**: Push/PR to main, weekly schedule (Mondays), manual

Advanced security analysis using GitHub CodeQL:

- Scans Python code for security vulnerabilities
- Runs `security-extended` and `security-and-quality` query suites
- Identifies potential security issues, bugs, and code quality problems
- Scheduled weekly scans to catch newly discovered vulnerabilities
- Results uploaded to GitHub Security tab

### 🔍 Static Analysis (`static-analysis.yml`)

**Triggers**: Push/PR to main, manual

Comprehensive static analysis and code quality checks:

- **Shell Script Validation**:
  - ShellCheck linting for bash scripts
  - Verifies scripts are executable
  - Validates bash syntax
  - Runs shfmt for formatting validation

- **Python Linting and Formatting**:
  - Black formatting validation
  - Flake8 linting for style and errors
  - Pylint code analysis
  - MyPy type checking

- **Security Scanning**:
  - pip-audit for dependency vulnerabilities
  - Gitleaks for secret detection

## Automated Dependency Management

### 🤖 Dependabot (`.github/dependabot.yml`)

**Schedule**: Weekly on Mondays at 09:00 UTC

Automated dependency updates for:

- **Python Dependencies (pip)**:
  - Weekly scans for outdated packages
  - Groups minor and patch updates together
  - Maximum 10 open PRs at once
  - Auto-labeled with `dependencies` and `python`
  - Commit message prefix: `deps`

- **GitHub Actions**:
  - Weekly scans for action updates
  - Groups all action updates together
  - Maximum 5 open PRs at once
  - Auto-labeled with `dependencies` and `github-actions`
  - Commit message prefix: `deps`

## Status Badges

Add these badges to your README.md:

```markdown
![CodeQL](https://github.com/YOUR_ORG/wbi-fleet-upgrade/workflows/CodeQL%20Security%20Analysis/badge.svg)
![Static Analysis](https://github.com/YOUR_ORG/wbi-fleet-upgrade/workflows/Static%20Analysis/badge.svg)
```

## Required Secrets

Workflows work out-of-the-box with `GITHUB_TOKEN`. No additional secrets required.

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

To update the Python version used in workflows, modify the `PYTHON_VERSION`
environment variable in `static-analysis.yml`:

```yaml
env:
  PYTHON_VERSION: "3.12"  # Update to new version
```

Also update in `codeql.yml`:

```yaml
- name: Set up Python
  uses: actions/setup-python@v5
  with:
    python-version: '3.12'  # Update to new version
```

### Customizing CodeQL Queries

Edit the queries in `codeql.yml`:

```yaml
queries: security-extended,security-and-quality  # Modify query suites
```

### Adjusting Dependabot Schedule

Modify the schedule in `.github/dependabot.yml`:

```yaml
schedule:
  interval: "daily"  # Change from "weekly" to "daily"
  day: "monday"      # Remove for daily schedule
  time: "09:00"      # Keep preferred time
```

## CI/CD Best Practices

1. **Always run workflows locally** before pushing
2. **Use `--dry-run`** when testing CLI changes
3. **Keep workflows fast** - use caching and matrix strategies
4. **Monitor workflow costs** - optimize runner usage
5. **Review security alerts** in the Security tab
6. **Update dependencies regularly** to get security fixes

## Troubleshooting

### Pre-commit Hook Fails

- Run `pre-commit run --all-files` locally
- Commit the auto-fixed changes
- Push the updated code

### Dependency Vulnerabilities

- Review the security report in workflow artifacts
- Update vulnerable packages in `requirements.txt`
- Test thoroughly after updates
- Review Dependabot PRs weekly and merge updates

### ShellCheck Warnings

- Review ShellCheck output
- Fix issues or add `# shellcheck disable=SCXXXX` if intentional
- Ensure scripts remain executable (`chmod +x *.sh`)

### Linting or Formatting Failures

- Run linters locally (black, flake8, pylint, mypy)
- Fix issues reported by the tools
- Ensure code follows project style guidelines

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
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Pre-commit Documentation](https://pre-commit.com/)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
