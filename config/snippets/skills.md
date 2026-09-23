
<!-- claude-toolkit:skills -->
## Skills

**AWS CDK:** `aws-cdk-core`, `aws-cdk-patterns`, `aws-cdk-lambda`, `aws-cdk-dynamodb`, `fargate-worker`
**Postgres:** `postgres-rls-multitenant`, `alembic-migrations`, `postgres-job-queue`
**Auth:** `descope-auth`
**React:** `react-core`, `react-state`, `web-ui-verify`, `playwright-e2e`
**Other:** `security`, `devops-cicd`, `spec-writing`

Skills load automatically. For AWS work, I follow Well-Architected principles (details in aws-cdk-core skill).

### Skill Combinations

Common multi-skill tasks:
- Add API endpoint → `aws-cdk-lambda` + `aws-cdk-patterns` + `security`
- Add Redux feature → `react-state` + `react-core`
- Verify a UI change visually → `web-ui-verify` + `react-core`
- Add a tenant-owned table → `alembic-migrations` + `postgres-rls-multitenant`
- Add a job class → `postgres-job-queue` + `fargate-worker`
- Add an authenticated endpoint → `descope-auth` + `aws-cdk-lambda` + `postgres-rls-multitenant`
- Automate a ticket's smoke test → `playwright-e2e` + `react-core`
- Deploy to prod → `devops-cicd` + `aws-cdk-core` + `security`
