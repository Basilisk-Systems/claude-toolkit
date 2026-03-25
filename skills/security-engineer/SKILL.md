---
name: security-engineer
description: Active security analysis agent for codebase auditing. TRIGGER when user asks for security review, security audit, threat modeling, or penetration testing analysis. Also triggers via /security-review command. Complements the 'security' skill (best practices) with active scanning and analysis.
allowed-tools: Read, Glob, Grep, Bash, Agent
---

# Security Engineer — Active Codebase Auditor

This skill performs active security analysis. It complements the `security` skill (which provides coding best practices) by systematically scanning and auditing a codebase.

---

## 1. Audit Methodology

Execute audits in this order:

1. **Reconnaissance** — Map the attack surface
2. **Static Analysis** — Scan for vulnerability patterns
3. **Configuration Review** — Check IaC for misconfigurations
4. **Dependency Audit** — Check for known vulnerable packages
5. **Report** — Structured findings with severity, location, and fix

### Step 1: Reconnaissance

Map the codebase attack surface before scanning:

```bash
# API endpoints (Python)
grep -rn "@app\.\(route\|get\|post\|put\|delete\|patch\)" --include="*.py"
grep -rn "APIRouter\|api_router" --include="*.py"

# API endpoints (CDK — API Gateway)
grep -rn "add_method\|add_resource\|LambdaRestApi\|HttpApi" --include="*.py"

# Auth boundaries
grep -rn "login\|authenticate\|authorize\|jwt\|token\|session" --include="*.py"

# Data stores
grep -rn "dynamodb\|Table\|s3\|Bucket\|cursor\|database" --include="*.py"

# External integrations
grep -rn "requests\.\(get\|post\|put\)\|urllib\|httpx\|aiohttp" --include="*.py"

# Secrets/credentials references
grep -rn "secret\|password\|api_key\|credential\|token" --include="*.py" --include="*.json" --include="*.yaml"
```

---

## 2. OWASP Top 10 Scan Patterns

### A01 — Broken Access Control

```bash
# Routes without auth decorators
grep -rn "@app.route\|@router\." --include="*.py" -l
# Then check each file for auth decorators: @login_required, @requires_auth, Depends(auth)

# Direct object references (user-controlled IDs without validation)
grep -rn "request\.\(args\|form\|json\)\[" --include="*.py"
grep -rn "event\[.path\|event\[.query" --include="*.py"

# Path traversal
grep -rn "os.path.join.*request\|open(.*request\|Path(.*request" --include="*.py"

# Missing authorization (accessing resources by ID without ownership check)
grep -rn "get_item\|get_object\|query(" --include="*.py" -A5
```

### A02 — Cryptographic Failures

```bash
# Weak hashing
grep -rn "hashlib.md5\|hashlib.sha1\|MD5\|SHA1" --include="*.py"

# Disabled TLS verification
grep -rn "verify=False\|verify\s*=\s*False\|CERT_NONE" --include="*.py"

# HTTP in production
grep -rn "http://" --include="*.py" --include="*.json" --include="*.yaml" --include="*.toml"

# Hardcoded encryption keys
grep -rn "encryption_key\s*=\s*\"\|aes_key\s*=\s*\"" --include="*.py"
```

### A03 — Injection

```bash
# SQL injection via f-strings
grep -rn 'f"SELECT\|f"INSERT\|f"UPDATE\|f"DELETE\|f"DROP' --include="*.py"
grep -rn "format(.*SELECT\|format(.*INSERT" --include="*.py"
grep -rn '%.*(SELECT\|INSERT\|UPDATE\|DELETE)' --include="*.py"

# Command injection
grep -rn "os.system(\|os.popen(\|subprocess.call(.*shell=True\|subprocess.Popen(.*shell=True" --include="*.py"

# Template injection
grep -rn "render_template_string\|Markup(\|safe\b" --include="*.py"

# NoSQL injection (DynamoDB)
grep -rn "FilterExpression.*f\"\|KeyConditionExpression.*f\"" --include="*.py"
```

### A04 — Insecure Design

Check for:
- Missing rate limiting on authentication endpoints
- No account lockout after failed attempts
- Business logic that can be bypassed by skipping steps
- Missing CSRF protection on state-changing endpoints

### A05 — Security Misconfiguration

```bash
# Debug mode in production
grep -rn "DEBUG\s*=\s*True\|debug=True\|\"debug\":\s*true" --include="*.py" --include="*.json"

# CORS wildcards
grep -rn 'allow_origins.*\["\*"\]\|Access-Control-Allow-Origin.*\*' --include="*.py"
grep -rn "cors.*allow_all\|CorsOptions.*allow_origins.*\*" --include="*.py"

# Verbose errors
grep -rn "traceback.format_exc\|traceback.print_exc\|str(e)" --include="*.py"

# Default credentials
grep -rn 'password.*=.*"admin\|password.*=.*"password\|password.*=.*"123' --include="*.py"
```

### A06 — Vulnerable Components

```bash
# Check Python dependencies
cat requirements*.txt pyproject.toml 2>/dev/null | grep -v "^#"

# Check for known problematic versions
# pip-audit or safety check (if available)
pip-audit 2>/dev/null || echo "pip-audit not installed"
```

### A07 — Authentication Failures

```bash
# Weak password policies
grep -rn "min.*length\|password.*policy\|PasswordPolicy" --include="*.py"

# JWT without expiry
grep -rn "jwt.encode\|jwt.decode" --include="*.py" -A5

# Session management issues
grep -rn "session\[.*=\|session\.get\|session_token" --include="*.py"

# Missing MFA configuration
grep -rn "mfa\|MfaConfiguration\|MFA" --include="*.py"
```

### A08 — Data Integrity Failures

```bash
# Unsafe deserialization
grep -rn "pickle.loads\|yaml.load(\|yaml.unsafe_load\|eval(\|exec(" --include="*.py"

# Missing integrity checks on downloads
grep -rn "urlretrieve\|download_file\|requests.get.*write" --include="*.py"
```

### A09 — Logging Failures

```bash
# PII in logs
grep -rn 'log.*password\|log.*token\|log.*secret\|log.*ssn\|log.*email.*=' --include="*.py" -i
grep -rn 'print(.*password\|print(.*token\|print(.*secret' --include="*.py" -i

# Missing audit logging
grep -rn "login\|authenticate\|delete\|admin" --include="*.py" -l
# Then check each file for corresponding log statements
```

### A10 — Server-Side Request Forgery (SSRF)

```bash
# User-controlled URLs in requests
grep -rn "requests\.\(get\|post\|put\|delete\)(.*\(request\|event\|input\|param\)" --include="*.py"
grep -rn "urllib.request.urlopen(.*\(request\|event\|input\)" --include="*.py"

# Unvalidated redirects
grep -rn "redirect(\|Location.*request\|url.*=.*request" --include="*.py"
```

---

## 3. AWS / CDK Security Checks

### IAM Policies

```bash
# Wildcard actions or resources
grep -rn '"*"\|actions=\[".*\*' --include="*.py" | grep -i "policy\|iam\|statement"

# Overly permissive managed policies
grep -rn "AmazonS3FullAccess\|AdministratorAccess\|PowerUserAccess\|AmazonDynamoDBFullAccess" --include="*.py"

# Missing conditions on IAM policies
grep -rn "PolicyStatement(" --include="*.py" -A10 | grep -v "conditions"
```

### S3 Buckets

```bash
# Missing encryption
grep -rn "s3.Bucket(" --include="*.py" -A10 | grep -v "encryption"

# Public access
grep -rn "public_read_access\|block_public_access.*False\|BlockPublicAccess.BLOCK_ALL" --include="*.py"

# Missing SSL enforcement
grep -rn "s3.Bucket(" --include="*.py" -A10 | grep -v "enforce_ssl"
```

### Lambda

```bash
# Overly permissive execution roles
grep -rn "lambda_.Function\|Function(" --include="*.py" -A20 | grep -i "role\|policy"

# Environment variable secrets (should use Secrets Manager)
grep -rn "environment.*secret\|environment.*password\|environment.*key" --include="*.py" -i
```

### API Gateway

```bash
# Routes without authorization
grep -rn "add_method\|add_route" --include="*.py" -A5 | grep -v "authoriz"

# Missing API key requirement
grep -rn "api_key_required" --include="*.py"
```

### Security Groups

```bash
# Open ingress (0.0.0.0/0)
grep -rn "0.0.0.0/0\|::/0\|Peer.any_ipv4\|Peer.any_ipv6" --include="*.py"

# Wide port ranges
grep -rn "Port.all_traffic\|Port.all_tcp" --include="*.py"
```

---

## 4. NIST 800-53 Control Mapping

| Control | Family | What to Check |
|---------|--------|---------------|
| AC-2 | Account Management | Cognito user pool config, IAM role assignments, user lifecycle |
| AC-3 | Access Enforcement | Authorization checks on all API endpoints |
| AC-6 | Least Privilege | IAM policies scoped to specific resources, no wildcards |
| AC-17 | Remote Access | VPN/VPC configuration, no direct public access to backends |
| AU-2 | Audit Events | CloudTrail enabled, application-level audit logging |
| AU-3 | Audit Content | Log format includes: who, what, when, where, outcome |
| AU-6 | Audit Review | CloudWatch alarms on security events |
| AU-11 | Audit Retention | Log retention >= 1 year (FedRAMP Moderate) |
| CM-2 | Baseline Config | CDK stacks define baseline, cdk-nag enforces |
| CM-6 | Config Settings | Security groups, NACLs, service configurations |
| IA-2 | MFA | Cognito MFA enforced, IAM MFA for console |
| IA-5 | Authenticator Mgmt | Password policy, token rotation, key rotation |
| SC-7 | Boundary Protection | VPC, security groups, WAF, NACLs |
| SC-8 | Transmission Confidentiality | TLS 1.2+, FIPS endpoints, no HTTP |
| SC-13 | Cryptographic Protection | KMS encryption, AWS-managed or CMK keys |
| SC-28 | Data at Rest | DynamoDB/S3/EBS encryption enabled |
| SI-2 | Flaw Remediation | Dependency scanning, patching cadence |
| SI-4 | System Monitoring | CloudWatch metrics, GuardDuty, Config rules |
| SI-10 | Input Validation | API input validation, sanitization, type checking |

---

## 5. Findings Report Format

Output all findings in this structure:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECURITY AUDIT REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Summary
- Critical: X | High: X | Medium: X | Low: X | Info: X
- Files scanned: X
- Attack surface: [API endpoints, data stores, auth mechanisms]

## Findings

### [CRITICAL] SQL Injection in Query Builder
- **Location**: `src/queries/builder.py:42`
- **Category**: OWASP A03 / CWE-89
- **Description**: User input concatenated directly into SQL query string
- **Evidence**:
  ```python
  query = f"SELECT * FROM events WHERE id = '{event_id}'"
  ```
- **Recommendation**: Use parameterized queries
  ```python
  query = "SELECT * FROM events WHERE id = :event_id"
  cursor.execute(query, {"event_id": event_id})
  ```
- **NIST Control**: SI-10 (Input Validation)

### [HIGH] Overly Permissive IAM Role
- **Location**: `infrastructure/stacks/api_stack.py:87`
- **Category**: CWE-269 / NIST AC-6
- **Description**: Lambda role uses `*` resource for DynamoDB actions
- **Evidence**:
  ```python
  actions=["dynamodb:*"], resources=["*"]
  ```
- **Recommendation**: Scope to specific table ARN and actions
  ```python
  actions=["dynamodb:GetItem", "dynamodb:PutItem"],
  resources=[table.table_arn]
  ```

## Positive Observations
- [List things done well — confirms good patterns and boosts morale]
- Example: "All S3 buckets enforce SSL and use KMS encryption"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Severity Definitions

| Severity | Criteria |
|----------|----------|
| **Critical** | Exploitable now, data breach risk, no auth bypass |
| **High** | Likely exploitable, requires specific conditions |
| **Medium** | Potential vulnerability, defense-in-depth gap |
| **Low** | Minor issue, best practice deviation |
| **Info** | Observation, no direct security impact |

---

## 6. Threat Modeling (STRIDE)

Apply STRIDE to each component identified during reconnaissance:

| Threat | Question | What to Check |
|--------|----------|---------------|
| **S**poofing | Can an attacker impersonate a user or service? | Auth mechanisms, token validation, API key management |
| **T**ampering | Can data be modified in transit or at rest? | TLS enforcement, data integrity checks, input validation |
| **R**epudiation | Can actions be denied? | Audit logging completeness, CloudTrail coverage |
| **I**nformation Disclosure | Can sensitive data leak? | Error messages, logs, API responses, S3 permissions |
| **D**enial of Service | Can the system be overwhelmed? | Rate limiting, Lambda concurrency, API throttling |
| **E**levation of Privilege | Can a user gain unauthorized access? | Role boundaries, IAM policies, Cognito group enforcement |

### Quick Threat Model Template

For each API endpoint or data flow:

```
Component: [name]
Entry points: [how users/systems interact]
Assets: [what data/resources are at risk]
Trust boundaries: [where auth/authz is checked]

| Threat | Risk | Mitigation | Status |
|--------|------|------------|--------|
| Spoofing | [H/M/L] | [control] | [implemented/missing] |
| Tampering | [H/M/L] | [control] | [implemented/missing] |
| Repudiation | [H/M/L] | [control] | [implemented/missing] |
| Info Disclosure | [H/M/L] | [control] | [implemented/missing] |
| DoS | [H/M/L] | [control] | [implemented/missing] |
| Elevation | [H/M/L] | [control] | [implemented/missing] |
```

---

## Scan Execution Checklist

When performing a security audit:

- [ ] Map all API endpoints and entry points
- [ ] Check each endpoint for authentication and authorization
- [ ] Run all OWASP A01-A10 scan patterns above
- [ ] Review all CDK/IaC for security misconfigurations
- [ ] Check dependency versions against known CVEs
- [ ] Verify encryption at rest for all data stores
- [ ] Verify encryption in transit (TLS, FIPS) for all connections
- [ ] Review logging for completeness and PII leakage
- [ ] Check IAM policies for least-privilege compliance
- [ ] Perform STRIDE analysis on critical data flows
- [ ] Produce findings report with severity ratings
- [ ] Include positive observations for good practices found
