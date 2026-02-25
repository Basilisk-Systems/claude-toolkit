---
name: devops-cicd
description: DevOps/DevSecOps skill for CI/CD pipeline validation. Use when creating or modifying GitHub Actions workflows, deployment scripts, or any CI/CD configuration. Automatically validates alignment with codebase.
---

# DevOps CI/CD Validation Skill

## When This Skill Activates

Automatically load this skill when working on:
- `.github/workflows/*.yml` files
- Deployment scripts (`scripts/deploy*.sh`)
- Docker/container configurations
- CDK pipeline code
- Any CI/CD related tasks

## Pre-Flight Validation Checklist

**BEFORE creating or modifying any CI/CD workflow, you MUST:**

### 1. Environment Variables Alignment

Check these files for environment variable requirements:

```bash
# Frontend environment files
web/.env
web/.env.dev
web/.env.staging
web/.env.prod

# Backend/CDK environment
.env
infrastructure/config/*.py
```

**Validate:**
- [ ] All `VITE_*` variables in `.env.*` files are set in workflow
- [ ] URLs match exactly (including www, trailing slashes)
- [ ] Boolean values are strings in workflows (`"true"` not `true`)
- [ ] API URLs match expected domains per environment

### 2. CDK Environment Naming

Check `app.py` for environment naming convention:

```bash
grep -E "env_name|try_get_context" app.py
```

**Common environments:**
| Context Value | Stack Prefix | Notes |
|--------------|--------------|-------|
| `dev` | `DocRanger-dev-` | Local development |
| `dev-{name}` | `DocRanger-dev-{name}-` | Personal dev stacks |
| `staging` | `DocRanger-staging-` | Shared staging |
| `prod` | `DocRanger-prod-` | Production |

**Validate:**
- [ ] `ENVIRONMENT` variable matches CDK context values exactly
- [ ] Stack names use correct prefix pattern
- [ ] `-c env=` flag matches `ENVIRONMENT` variable

### 3. Build Commands Alignment

Check package.json for correct build scripts:

```bash
# Frontend
cat web/package.json | jq '.scripts'

# Backend/Python
cat pyproject.toml | grep -A 20 "\[tool.pytest"
```

**Validate:**
- [ ] `npm ci` (not `npm install`) for CI reproducibility
- [ ] Build commands match package.json scripts exactly
- [ ] Test commands include coverage flags if required
- [ ] Python commands use correct virtual env or requirements file

### 4. Secrets and Credentials

**Required GitHub Secrets per environment:**

| Secret | Staging | Production | Notes |
|--------|---------|------------|-------|
| `AWS_DEPLOY_ROLE_ARN` | ✅ | ❌ | Staging OIDC role |
| `AWS_DEPLOY_ROLE_ARN_PROD` | ❌ | ✅ | Production OIDC role |
| `DISCORD_WEBHOOK_URL` | ✅ | ✅ | Notifications |

**Validate:**
- [ ] All `${{ secrets.* }}` references have documented setup steps
- [ ] No hardcoded credentials, tokens, or ARNs
- [ ] OIDC permissions block included for AWS auth

### 5. Domain and URL Consistency

**Check domain configuration:**

```bash
# CDK domain config
grep -r "domain\|url\|URL" infrastructure/

# Frontend env files
grep -E "URL|BASE" web/.env*
```

**Common patterns to verify:**
| Environment | Frontend URL | API URL |
|-------------|--------------|---------|
| dev | `dev.docranger.io` | Stack output |
| staging | `staging.docranger.io` | Stack output |
| prod | `www.docranger.io` | `api.docranger.io` |

---

## Validation Commands

Run these before committing CI/CD changes:

### Quick Validation Script

```bash
# Check env var alignment
echo "=== Frontend Env Files ==="
for f in web/.env*; do echo "--- $f ---"; cat $f; done

echo "=== CDK Environment Config ==="
grep -E "env_name|ENVIRONMENT" app.py

echo "=== Workflow Environments ==="
grep -E "ENVIRONMENT:|VITE_" .github/workflows/*.yml
```

### CDK Synth Test

```bash
# Verify CDK synthesizes for each environment
cdk synth --all -c env=staging 2>&1 | head -20
cdk synth --all -c env=prod 2>&1 | head -20
```

---

## Common Mistakes to Catch

### 1. URL Mismatches
```yaml
# WRONG - missing www for production
VITE_BASE_URL: https://docranger.io

# CORRECT
VITE_BASE_URL: https://www.docranger.io
```

### 2. Environment Name Mismatch
```yaml
# WRONG - CDK uses "prod", not "production"
ENVIRONMENT: production

# CORRECT
ENVIRONMENT: prod
```

### 3. Boolean String Values
```yaml
# WRONG - YAML boolean, not string
VITE_AUTH_BYPASS: false

# CORRECT - Must be string for Vite
VITE_AUTH_BYPASS: "false"
```

### 4. Hardcoded Stack Names
```yaml
# WRONG - hardcoded
--stack-name DocRanger-prod-Api

# CORRECT - use environment variable
--stack-name DocRanger-${{ env.ENVIRONMENT }}-Api
```

### 5. Missing CDK Context
```yaml
# WRONG - missing -c env flag
cdk deploy DocRanger-prod-Api

# CORRECT
cdk deploy DocRanger-${{ env.ENVIRONMENT }}-Api -c env=${{ env.ENVIRONMENT }}
```

---

## GitHub Actions Patterns

### OIDC Authentication
```yaml
permissions:
  id-token: write
  contents: read

- name: Configure AWS credentials (OIDC)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
    role-session-name: GitHubActions-Deploy
    aws-region: us-east-1
```

### Environment Protection (Production)
```yaml
jobs:
  deploy:
    environment:
      name: production
      url: https://www.docranger.io
```

### GitHub Environment Limitations (Team Plan)

**IMPORTANT:** GitHub Team plan has limited environment features compared to Enterprise.

| Feature | Team Plan | Enterprise |
|---------|-----------|------------|
| Environment secrets | ✅ | ✅ |
| Environment variables | ✅ | ✅ |
| Deployment branches/tags | ✅ | ✅ |
| Required reviewers (approval gates) | ❌ | ✅ |
| Wait timer | ❌ | ✅ |
| Custom deployment protection rules | ❌ | ✅ |

**Workarounds for Team plan:**
1. **Branch protection on `main`** - Require PR reviews before merging
2. **Tag protection rules** - Restrict who can push version tags
3. **Workflow-level checks** - Verify branch in workflow code
4. **Manual confirmation inputs** - `workflow_dispatch` with confirmation text

```yaml
# Team plan pattern: Use workflow confirmation instead of environment approval
on:
  workflow_dispatch:
    inputs:
      confirmation:
        description: "Type 'prod' to confirm"
        required: true
        type: string

jobs:
  validate:
    steps:
      - name: Validate confirmation
        run: |
          if [[ "${{ github.event.inputs.confirmation }}" != "prod" ]]; then
            echo "::error::Confirmation mismatch!"
            exit 1
          fi
```

**Do NOT document "required reviewers" for environments on Team plan** - this feature doesn't exist.

### Concurrency Control
```yaml
concurrency:
  group: deploy-${{ github.ref_name }}
  cancel-in-progress: false  # Don't cancel deployments
```

### CDK Synthesis Placeholder
```yaml
# CDK synthesizes ALL stacks even with --exclusively
# Create placeholder for stacks that need build artifacts
- name: Create placeholder for CDK synthesis
  run: mkdir -p web/dist && echo "placeholder" > web/dist/index.html
```

---

## Security Checklist for CI/CD

- [ ] No long-lived AWS access keys (use OIDC)
- [ ] Secrets referenced via `${{ secrets.* }}`, never hardcoded
- [ ] Production deploys require approval gate
- [ ] Production deploys only from `main` branch
- [ ] Workflows don't expose secrets in logs
- [ ] Dependencies pinned to specific versions (not `latest`)
- [ ] Security scanning included (Bandit, Trivy, etc.)

---

## Workflow Validation Prompt

When asked to create or modify a CI/CD workflow, always:

1. **Read first:** Check `.env.*` files, `app.py`, `package.json`
2. **Compare:** Verify all env vars and commands match source files
3. **Document:** Note any required manual setup (secrets, environments)
4. **Test:** Suggest `cdk synth` or dry-run commands to validate

**Template question to ask yourself:**
> "Have I checked all `.env.*` files to ensure the workflow environment variables match exactly?"
