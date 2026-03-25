---
name: aws-govcloud
description: AWS GovCloud patterns for partition-aware CDK, FIPS endpoints, and service availability. TRIGGER when code targets GovCloud (arn:aws-us-gov, us-gov-* regions), uses FIPS endpoints, or user mentions GovCloud, FedRAMP deployment, or government cloud. Do NOT trigger for commercial AWS.
---

# AWS GovCloud Patterns

## 1. GovCloud Fundamentals

| Property | Value |
|----------|-------|
| Partition | `aws-us-gov` |
| Regions | `us-gov-west-1`, `us-gov-east-1` |
| ARN format | `arn:aws-us-gov:service:region:account:resource` |
| URL suffix | `amazonaws.com` (same as commercial) |
| Global services | **None** — IAM, Route53, CloudFront are regional or unavailable |
| Account | Separate signup, linked to commercial account |

---

## 2. CDK Partition Awareness

**CRITICAL**: Never hardcode `arn:aws` — always use CDK tokens.

```python
from aws_cdk import Aws

# These resolve at deploy time to the correct partition
Aws.PARTITION     # "aws-us-gov" in GovCloud, "aws" in commercial
Aws.REGION        # "us-gov-west-1"
Aws.ACCOUNT_ID    # "123456789012"
Aws.URL_SUFFIX    # "amazonaws.com"
```

### WRONG vs RIGHT

**S3 Bucket ARN:**
```python
# WRONG
f"arn:aws:s3:::{bucket_name}"

# RIGHT
f"arn:{Aws.PARTITION}:s3:::{bucket_name}"
# Or use CDK construct: bucket.bucket_arn
```

**Lambda Function ARN:**
```python
# WRONG
f"arn:aws:lambda:us-east-1:{account}:function:{fn_name}"

# RIGHT
f"arn:{Aws.PARTITION}:lambda:{Aws.REGION}:{Aws.ACCOUNT_ID}:function:{fn_name}"
# Or use CDK construct: fn.function_arn
```

**IAM Role ARN:**
```python
# WRONG
f"arn:aws:iam::{account}:role/{role_name}"

# RIGHT
f"arn:{Aws.PARTITION}:iam::{Aws.ACCOUNT_ID}:role/{role_name}"
# Or use CDK construct: role.role_arn
```

**DynamoDB Table ARN:**
```python
# WRONG
f"arn:aws:dynamodb:us-east-1:{account}:table/{table_name}"

# RIGHT
f"arn:{Aws.PARTITION}:dynamodb:{Aws.REGION}:{Aws.ACCOUNT_ID}:table/{table_name}"
# Or use CDK construct: table.table_arn
```

**Bedrock Model ARN:**
```python
# WRONG
f"arn:aws:bedrock:us-east-1::foundation-model/{model_id}"

# RIGHT
f"arn:{Aws.PARTITION}:bedrock:{Aws.REGION}::foundation-model/{model_id}"
```

**Rule**: Always prefer CDK construct properties (`.bucket_arn`, `.function_arn`, `.table_arn`) over manual ARN construction. They handle partition automatically.

---

## 3. FIPS Endpoints

Use FIPS endpoints for all data-in-transit in FedRAMP workloads.

### boto3 Configuration

```python
import boto3

# Option 1: Explicit endpoint URL
client = boto3.client(
    "s3",
    region_name="us-gov-west-1",
    endpoint_url="https://s3-fips.us-gov-west-1.amazonaws.com",
)

# Option 2: Use FIPS region (preferred for some services)
client = boto3.client(
    "sts",
    region_name="us-gov-west-1",
    endpoint_url="https://sts.us-gov-west-1.amazonaws.com",  # FIPS by default in GovCloud
)
```

### Common FIPS Endpoint URLs

| Service | FIPS Endpoint |
|---------|--------------|
| S3 | `https://s3-fips.us-gov-west-1.amazonaws.com` |
| DynamoDB | `https://dynamodb.us-gov-west-1.amazonaws.com` (FIPS by default) |
| Lambda | `https://lambda.us-gov-west-1.amazonaws.com` (FIPS by default) |
| STS | `https://sts.us-gov-west-1.amazonaws.com` |
| Secrets Manager | `https://secretsmanager.us-gov-west-1.amazonaws.com` |
| Bedrock Runtime | `https://bedrock-runtime-fips.us-gov-west-1.amazonaws.com` |
| KMS | `https://kms-fips.us-gov-west-1.amazonaws.com` |
| CloudWatch | `https://monitoring.us-gov-west-1.amazonaws.com` |

### CDK VPC Endpoint with FIPS

```python
from aws_cdk import aws_ec2 as ec2

# S3 gateway endpoint (uses FIPS automatically in GovCloud)
vpc.add_gateway_endpoint(
    "S3Endpoint",
    service=ec2.GatewayVpcEndpointAwsService.S3,
)

# DynamoDB gateway endpoint
vpc.add_gateway_endpoint(
    "DynamoEndpoint",
    service=ec2.GatewayVpcEndpointAwsService.DYNAMODB,
)

# Interface endpoints for services without gateway support
vpc.add_interface_endpoint(
    "SecretsManagerEndpoint",
    service=ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
    private_dns_enabled=True,
)
```

---

## 4. Service Availability Matrix

| Service | Available | Notes |
|---------|-----------|-------|
| Lambda | Yes | Same as commercial |
| DynamoDB | Yes | Same as commercial |
| API Gateway | Yes | REST and HTTP APIs |
| Cognito | Yes | User Pools + Identity Pools |
| Bedrock | Yes | Limited models, Cross-Region Inference |
| Step Functions | Yes | Standard + Express |
| S3 | Yes | Regional endpoints only |
| SQS / SNS | Yes | Same as commercial |
| EventBridge | Yes | Same as commercial |
| CloudWatch | Yes | Same as commercial |
| CloudTrail | Yes | Regional only |
| WAF v2 | Yes | Regional only |
| KMS | Yes | Same as commercial |
| Secrets Manager | Yes | Same as commercial |
| ACM | Yes | Regional only (no global) |
| ECR | Yes | Regional endpoint |
| ECS / Fargate | Yes | Same as commercial |
| Route53 | Yes | **Regional only** — no global hosted zones |
| CloudFront | **No** | Use ALB + S3 directly |
| Amplify | **No** | Use S3 + CloudWatch |
| AppSync | Yes | Same as commercial |
| GuardDuty | Yes | Regional |
| Config | Yes | Regional |
| Systems Manager | Yes | Parameter Store + SSM Agent |

---

## 5. SSO Profile Configuration

### ~/.aws/config

```ini
[profile govcloud-dev]
sso_start_url = https://my-org.awsapps.com/start
sso_region = us-gov-west-1
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
region = us-gov-west-1
output = json

[profile govcloud-staging]
sso_start_url = https://my-org.awsapps.com/start
sso_region = us-gov-west-1
sso_account_id = 234567890123
sso_role_name = PowerUserAccess
region = us-gov-west-1
output = json
```

### Deploy Commands

```bash
# Login (opens browser)
aws sso login --profile govcloud-dev

# CDK commands
cdk synth --profile govcloud-dev
cdk diff --profile govcloud-dev
cdk deploy --profile govcloud-dev --all

# Verify identity
aws sts get-caller-identity --profile govcloud-dev
```

### boto3 Session with SSO Profile

```python
import boto3

session = boto3.Session(profile_name="govcloud-dev")
client = session.client("bedrock-runtime")
```

---

## 6. CDK Context for GovCloud

### cdk.json

```json
{
  "app": "python3 app.py",
  "context": {
    "@aws-cdk/core:target-partitions": ["aws-us-gov"],
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/aws-s3:serverAccessLogsUseBucketPolicy": true
  }
}
```

### Environment Configuration Pattern

```python
# config/environments.py
from dataclasses import dataclass
from aws_cdk import Environment


@dataclass
class EnvConfig:
    env_name: str
    account_id: str
    region: str
    prefix: str
    is_govcloud: bool = False

    @property
    def cdk_env(self) -> Environment:
        return Environment(account=self.account_id, region=self.region)

    @property
    def partition(self) -> str:
        return "aws-us-gov" if self.is_govcloud else "aws"


ENVIRONMENTS = {
    "dev": EnvConfig(
        env_name="dev",
        account_id="123456789012",
        region="us-gov-west-1",
        prefix="odin-dev",
        is_govcloud=True,
    ),
    "staging": EnvConfig(
        env_name="staging",
        account_id="234567890123",
        region="us-gov-west-1",
        prefix="odin-staging",
        is_govcloud=True,
    ),
}
```

---

## 7. Common Gotchas

### S3 Regional URLs
```python
# GovCloud S3 URLs include the region
# https://s3.us-gov-west-1.amazonaws.com/bucket-name/key
# NOT https://s3.amazonaws.com/bucket-name/key (commercial global)
```

### ECR Registry
```python
# GovCloud ECR
# {account}.dkr.ecr.us-gov-west-1.amazonaws.com
# NOT {account}.dkr.ecr.us-east-1.amazonaws.com
```

### ACM Certificates
- Regional only — no `us-east-1` global certs
- Each region needs its own certificate
- No CloudFront distribution certs (CloudFront unavailable)

### STS
- Must use regional endpoint in GovCloud
- Global STS endpoint (`sts.amazonaws.com`) does NOT work
- boto3 defaults to regional in GovCloud — verify your SDK version

### Cross-Account Access
- GovCloud accounts can only access other GovCloud accounts
- No cross-partition (GovCloud ↔ Commercial) role assumption
- Service-linked roles work the same way

### CDK Bootstrap
```bash
# Bootstrap with GovCloud qualifier
cdk bootstrap aws://123456789012/us-gov-west-1 --profile govcloud-dev
```

---

## 8. Testing in GovCloud

### moto Mock with GovCloud Region

```python
import pytest
import boto3
from moto import mock_aws


@pytest.fixture
def govcloud_session():
    """Create a boto3 session targeting GovCloud region."""
    with mock_aws():
        session = boto3.Session(region_name="us-gov-west-1")
        yield session


def test_s3_in_govcloud(govcloud_session):
    s3 = govcloud_session.client("s3")
    s3.create_bucket(
        Bucket="test-bucket",
        CreateBucketConfiguration={"LocationConstraint": "us-gov-west-1"},
    )
    response = s3.list_buckets()
    assert len(response["Buckets"]) == 1
```

### CDK Snapshot Tests with Partition Assertions

```python
from aws_cdk import App
from aws_cdk.assertions import Template


def test_stack_uses_govcloud_partition():
    app = App()
    stack = MyStack(app, "TestStack", env=cdk.Environment(
        account="123456789012", region="us-gov-west-1",
    ))
    template = Template.from_stack(stack)

    # Verify no hardcoded "arn:aws:" in the template
    template_json = template.to_json()
    assert "arn:aws:" not in str(template_json), "Hardcoded 'arn:aws:' found — use Aws.PARTITION"
```

### Integration Test Markers

```python
# conftest.py
def pytest_configure(config):
    config.addinivalue_line("markers", "govcloud: requires GovCloud credentials")
    config.addinivalue_line("markers", "integration: hits real AWS APIs")


# test_govcloud.py
@pytest.mark.govcloud
@pytest.mark.integration
def test_real_govcloud_access():
    """Run with: pytest -m govcloud"""
    session = boto3.Session(profile_name="govcloud-dev")
    sts = session.client("sts")
    identity = sts.get_caller_identity()
    assert identity["Account"] is not None

```

---

## Security Checklist

Before deploying to GovCloud, verify:

- [ ] No hardcoded `arn:aws:` — all use `Aws.PARTITION` or construct properties
- [ ] FIPS endpoints configured for data-in-transit services
- [ ] VPC endpoints for all services accessed from private subnets
- [ ] SSO profiles configured (no long-lived access keys)
- [ ] CloudTrail enabled in all regions
- [ ] S3 buckets enforce SSL (`enforce_ssl=True`)
- [ ] Encryption at rest on all data stores (DynamoDB, S3, EBS)
- [ ] KMS key rotation enabled
- [ ] Security groups follow least-privilege (no `0.0.0.0/0` ingress)
- [ ] Lambda functions use latest Python runtime
