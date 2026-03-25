---
name: fedramp-compliance
description: FedRAMP Moderate compliance patterns with cdk-nag, NIST 800-53 controls, and AWS security baselines. TRIGGER when code uses cdk-nag, NagSuppressions, NIST800-53 checks, or user mentions FedRAMP, compliance, ATO, or security controls. Do NOT trigger for general security best practices (use 'security' skill instead).
---

# FedRAMP Moderate Compliance Patterns

## 1. cdk-nag Setup

Add cdk-nag to enforce compliance at synth time:

```python
# pyproject.toml dependency
# cdk-nag>=2.28.0

# app.py — apply nag checks to ALL stacks
import cdk_nag
from aws_cdk import App, Aspects

app = App()

# NIST 800-53 rev5 checks cover FedRAMP Moderate
Aspects.of(app).add(cdk_nag.AwsSolutionsChecks(verbose=True))
Aspects.of(app).add(cdk_nag.NIST80053R5Checks(verbose=True))

# Build stacks AFTER adding aspects
# ...
app.synth()
```

Run `cdk synth` to see all nag findings. **Fix findings before deploying — never suppress without review.**

---

## 2. Common cdk-nag Rules and Fixes

### AwsSolutions-IAM4 — No AWS Managed Policies

```python
from aws_cdk import Aws, aws_iam as iam

# WRONG — managed policies are too broad
role.add_managed_policy(
    iam.ManagedPolicy.from_aws_managed_policy_name("AmazonS3FullAccess")
)

# RIGHT — inline policy with least privilege
role.add_to_policy(iam.PolicyStatement(
    actions=["s3:GetObject", "s3:PutObject"],
    resources=[f"arn:{Aws.PARTITION}:s3:::{bucket_name}/*"],
))
```

### AwsSolutions-IAM5 — No Wildcard Permissions

```python
# WRONG
iam.PolicyStatement(actions=["s3:*"], resources=["*"])

# RIGHT
iam.PolicyStatement(
    actions=["s3:GetObject", "s3:PutObject"],
    resources=[bucket.bucket_arn + "/*"],
)
```

**Exception**: `AWSLambdaBasicExecutionRole` for CloudWatch Logs is acceptable — suppress with reason.

### AwsSolutions-S1 — S3 Server Access Logging

```python
from aws_cdk import aws_s3 as s3, RemovalPolicy

access_logs_bucket = s3.Bucket(
    self, "AccessLogs",
    encryption=s3.BucketEncryption.S3_MANAGED,
    enforce_ssl=True,
    block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
    removal_policy=RemovalPolicy.RETAIN,
)

data_bucket = s3.Bucket(
    self, "DataBucket",
    server_access_logs_bucket=access_logs_bucket,
    server_access_logs_prefix="data-bucket/",
    encryption=s3.BucketEncryption.KMS,
    enforce_ssl=True,
    block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
    versioned=True,
)
```

### AwsSolutions-S10 — S3 Enforce SSL

```python
bucket = s3.Bucket(self, "Bucket",
    enforce_ssl=True,  # Adds deny policy for non-SSL requests
)
```

### AwsSolutions-DDB3 — DynamoDB Point-in-Time Recovery

```python
from aws_cdk import aws_dynamodb as dynamodb

table = dynamodb.Table(
    self, "EventsTable",
    partition_key=dynamodb.Attribute(name="pk", type=dynamodb.AttributeType.STRING),
    sort_key=dynamodb.Attribute(name="sk", type=dynamodb.AttributeType.STRING),
    point_in_time_recovery=True,  # Required for FedRAMP
    encryption=dynamodb.TableEncryption.AWS_MANAGED,  # or CUSTOMER_MANAGED for stricter
)
```

### AwsSolutions-L1 — Lambda Latest Runtime

```python
from aws_cdk import aws_lambda as lambda_

fn = lambda_.Function(
    self, "Handler",
    runtime=lambda_.Runtime.PYTHON_3_12,  # Always latest stable
    handler="handler.lambda_handler",
    code=lambda_.Code.from_asset("src/handlers"),
)
```

### AwsSolutions-APIG1 — API Gateway Access Logging

```python
from aws_cdk import aws_apigateway as apigw, aws_logs as logs

api_log_group = logs.LogGroup(self, "ApiLogs", retention=logs.RetentionDays.ONE_YEAR)

api = apigw.RestApi(
    self, "Api",
    deploy_options=apigw.StageOptions(
        access_log_destination=apigw.LogGroupLogDestination(api_log_group),
        access_log_format=apigw.AccessLogFormat.json_with_standard_fields(
            caller=True,
            http_method=True,
            ip=True,
            protocol=True,
            request_time=True,
            resource_path=True,
            response_length=True,
            status=True,
            user=True,
        ),
        logging_level=apigw.MethodLoggingLevel.INFO,
    ),
)
```

### AwsSolutions-APIG4 — API Gateway Authorization

```python
# Every method MUST have authorization
api.root.add_resource("events").add_method(
    "GET",
    handler_integration,
    authorization_type=apigw.AuthorizationType.COGNITO,
    authorizer=cognito_authorizer,
)
```

### AwsSolutions-COG1 — Cognito Strong Password Policy

```python
from aws_cdk import aws_cognito as cognito

user_pool = cognito.UserPool(
    self, "UserPool",
    password_policy=cognito.PasswordPolicy(
        min_length=12,
        require_lowercase=True,
        require_uppercase=True,
        require_digits=True,
        require_symbols=True,
        temp_valid_duration=Duration.days(1),
    ),
    advanced_security_mode=cognito.AdvancedSecurityMode.ENFORCED,
)
```

### AwsSolutions-COG2 — Cognito MFA

```python
user_pool = cognito.UserPool(
    self, "UserPool",
    mfa=cognito.Mfa.REQUIRED,
    mfa_second_factor=cognito.MfaSecondFactor(
        otp=True,
        sms=False,  # TOTP preferred over SMS for FedRAMP
    ),
)
```

### AwsSolutions-KMS5 — KMS Key Rotation

```python
from aws_cdk import aws_kms as kms

key = kms.Key(
    self, "DataKey",
    enable_key_rotation=True,  # Required for FedRAMP
    description="Encryption key for application data",
    alias="alias/odin-data-key",
)
```

---

## 3. NagSuppressions (When Legitimate)

Suppress ONLY with a documented reason and team review:

```python
from cdk_nag import NagSuppressions

# Resource-level suppression
NagSuppressions.add_resource_suppressions(
    construct=lambda_fn,
    suppressions=[
        {
            "id": "AwsSolutions-IAM4",
            "reason": "AWSLambdaBasicExecutionRole is required for CloudWatch Logs — "
                      "scoped to the function's log group by default",
        },
    ],
)

# Stack-level suppression (use sparingly)
NagSuppressions.add_stack_suppressions(
    stack=self,
    suppressions=[
        {
            "id": "AwsSolutions-IAM5",
            "reason": "CDK-generated policies for custom resources use wildcards — "
                      "these are deploy-time only and scoped to the stack",
            "applies_to": [
                "Resource::*",
            ],
        },
    ],
)
```

### Suppression Rules

1. **ALWAYS** include a specific, detailed reason
2. **NEVER** suppress critical controls (encryption, auth) without architect review
3. **Prefer fixing** over suppressing — only suppress when the control is not applicable
4. **Use `applies_to`** to narrow suppression scope when possible
5. **Document** all suppressions in a central tracking file or PR description
6. **Review** suppressions during code review — they are security decisions

---

## 4. FedRAMP Moderate Control Families → CDK

| Control | Requirement | CDK Implementation |
|---------|------------|-------------------|
| AC-2 | Account Management | Cognito UserPool, admin APIs for lifecycle |
| AC-3 | Access Enforcement | API Gateway authorizers, Cognito groups |
| AC-6 | Least Privilege | Scoped IAM PolicyStatements, no wildcards |
| AU-2 | Audit Events | CloudTrail (all regions), API Gateway logging |
| AU-3 | Audit Content | Structured JSON logs with who/what/when/outcome |
| AU-6 | Audit Review | CloudWatch Alarms on security events |
| AU-11 | Audit Retention | Log retention >= 1 year |
| CM-2 | Baseline Config | CDK stacks ARE the baseline — version controlled |
| CM-6 | Config Settings | AWS Config rules for drift detection |
| IA-2 | MFA | Cognito `mfa=Mfa.REQUIRED`, TOTP preferred |
| IA-5 | Authenticator Mgmt | Password policy, Secrets Manager rotation |
| SC-7 | Boundary Protection | VPC, Security Groups, WAF, NACLs |
| SC-8 | Transmission Confidentiality | TLS 1.2+ policy, FIPS endpoints |
| SC-13 | Cryptographic Protection | KMS with rotation, no self-managed keys |
| SC-28 | Data at Rest | DynamoDB/S3/EBS encryption, KMS CMK |
| SI-2 | Flaw Remediation | Dependency scanning in CI, patching SLA |
| SI-4 | System Monitoring | GuardDuty, CloudWatch, Config |
| SI-10 | Input Validation | API request validation, type checking |

---

## 5. Encryption Patterns

### DynamoDB — AWS Managed KMS

```python
table = dynamodb.Table(
    self, "Table",
    encryption=dynamodb.TableEncryption.AWS_MANAGED,
    # Or for customer-managed key:
    # encryption=dynamodb.TableEncryption.CUSTOMER_MANAGED,
    # encryption_key=key,
)
```

### S3 — SSE-KMS

```python
bucket = s3.Bucket(
    self, "Bucket",
    encryption=s3.BucketEncryption.KMS,
    encryption_key=key,  # Customer-managed KMS key
    bucket_key_enabled=True,  # Reduces KMS API calls
    enforce_ssl=True,
)
```

### Lambda Environment Variables — Encryption

```python
fn = lambda_.Function(
    self, "Handler",
    environment_encryption=key,  # KMS key for env var encryption
    environment={
        "TABLE_NAME": table.table_name,
        # Never put secrets here — use Secrets Manager
    },
)
```

### API Gateway — TLS Policy

```python
from aws_cdk import aws_apigateway as apigw

domain = apigw.DomainName(
    self, "ApiDomain",
    domain_name="api.example.gov",
    certificate=cert,
    security_policy=apigw.SecurityPolicy.TLS_1_2,  # Minimum for FedRAMP
)
```

---

## 6. Logging and Auditing

### CloudTrail — Multi-Region

```python
from aws_cdk import aws_cloudtrail as cloudtrail

trail = cloudtrail.Trail(
    self, "AuditTrail",
    is_multi_region_trail=True,
    include_global_service_events=True,
    enable_file_validation=True,  # Required for FedRAMP — integrity verification
    bucket=audit_logs_bucket,
    send_to_cloud_watch_logs=True,
    cloud_watch_logs_group=trail_log_group,
    cloud_watch_log_group_retention=logs.RetentionDays.ONE_YEAR,  # FedRAMP minimum
)
```

### VPC Flow Logs

```python
from aws_cdk import aws_ec2 as ec2

vpc.add_flow_log(
    "FlowLog",
    destination=ec2.FlowLogDestination.to_cloud_watch_logs(
        flow_log_group,
        flow_log_role,
    ),
    traffic_type=ec2.FlowLogTrafficType.ALL,
)
```

### Application Logging (Structured JSON)

```python
# Use Lambda Powertools for structured logging
from aws_lambda_powertools import Logger

logger = Logger(service="odin-detection")

@logger.inject_lambda_context(log_event=True)
def handler(event, context):
    logger.info("Processing detection request", extra={
        "user_id": event.get("requestContext", {}).get("authorizer", {}).get("sub"),
        "action": "detect_threats",
        "resource": event.get("path"),
    })
```

### Log Retention

```python
# All log groups must have retention set (FedRAMP: >= 1 year)
log_group = logs.LogGroup(
    self, "AppLogs",
    retention=logs.RetentionDays.ONE_YEAR,
    removal_policy=RemovalPolicy.RETAIN,
)
```

---

## 7. WAF Configuration

```python
from aws_cdk import aws_wafv2 as wafv2

web_acl = wafv2.CfnWebACL(
    self, "WebACL",
    scope="REGIONAL",
    default_action=wafv2.CfnWebACL.DefaultActionProperty(allow={}),
    visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
        cloud_watch_metrics_enabled=True,
        metric_name="OdinWAF",
        sampled_requests_enabled=True,
    ),
    rules=[
        # AWS Managed Rules — Core Rule Set
        wafv2.CfnWebACL.RuleProperty(
            name="AWSManagedRulesCommonRuleSet",
            priority=1,
            override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
            statement=wafv2.CfnWebACL.StatementProperty(
                managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                    vendor_name="AWS",
                    name="AWSManagedRulesCommonRuleSet",
                ),
            ),
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="CommonRules",
                sampled_requests_enabled=True,
            ),
        ),
        # SQL Injection Protection
        wafv2.CfnWebACL.RuleProperty(
            name="AWSManagedRulesSQLiRuleSet",
            priority=2,
            override_action=wafv2.CfnWebACL.OverrideActionProperty(none={}),
            statement=wafv2.CfnWebACL.StatementProperty(
                managed_rule_group_statement=wafv2.CfnWebACL.ManagedRuleGroupStatementProperty(
                    vendor_name="AWS",
                    name="AWSManagedRulesSQLiRuleSet",
                ),
            ),
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="SQLiRules",
                sampled_requests_enabled=True,
            ),
        ),
        # Rate Limiting
        wafv2.CfnWebACL.RuleProperty(
            name="RateLimit",
            priority=3,
            action=wafv2.CfnWebACL.RuleActionProperty(block={}),
            statement=wafv2.CfnWebACL.StatementProperty(
                rate_based_statement=wafv2.CfnWebACL.RateBasedStatementProperty(
                    limit=2000,
                    aggregate_key_type="IP",
                ),
            ),
            visibility_config=wafv2.CfnWebACL.VisibilityConfigProperty(
                cloud_watch_metrics_enabled=True,
                metric_name="RateLimit",
                sampled_requests_enabled=True,
            ),
        ),
    ],
)

# Associate with API Gateway
wafv2.CfnWebACLAssociation(
    self, "WebACLAssociation",
    resource_arn=api.deployment_stage.stage_arn,
    web_acl_arn=web_acl.attr_arn,
)
```

---

## Compliance Checklist

Before ATO submission, verify:

- [ ] cdk-nag AwsSolutions + NIST80053R5 checks pass (or suppressions documented)
- [ ] All data encrypted at rest (DynamoDB, S3, EBS, logs)
- [ ] All data encrypted in transit (TLS 1.2+, FIPS endpoints)
- [ ] CloudTrail enabled (multi-region, file validation, 1yr retention)
- [ ] VPC Flow Logs enabled
- [ ] WAF deployed with core rules + rate limiting
- [ ] Cognito MFA required (TOTP, not SMS)
- [ ] Password policy meets complexity requirements (12+ chars)
- [ ] IAM policies use least privilege (no wildcards)
- [ ] API Gateway has authorization on all routes
- [ ] S3 buckets block public access and enforce SSL
- [ ] KMS key rotation enabled
- [ ] Log retention >= 1 year on all log groups
- [ ] GuardDuty enabled
- [ ] AWS Config rules enabled for drift detection
- [ ] All nag suppressions documented with rationale
