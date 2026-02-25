---
name: aws-cdk-core
description: AWS CDK v2 core patterns - app structure, configuration, stacks, and deployment. Use when setting up CDK projects, creating stacks, or deploying infrastructure.
---

# AWS CDK Core Patterns

## Tech Stack
- **IaC**: AWS CDK v2 (Python)
- **Runtime**: Python 3.11+
- **Deploy**: CDK CLI (local), CDK Pipelines (CI/CD)

---

## Project Structure

```
infrastructure/
├── app.py                    # CDK app entry point
├── cdk.json                  # CDK configuration
├── requirements.txt          # CDK dependencies
├── stacks/
│   ├── __init__.py
│   ├── api_stack.py
│   ├── database_stack.py
│   └── auth_stack.py
├── constructs/              # Reusable L3 constructs
│   └── __init__.py
└── config/
    ├── dev.py
    ├── staging.py
    └── prod.py
```

---

## App Entry Point (app.py)

```python
#!/usr/bin/env python3
import os
import aws_cdk as cdk
from stacks.api_stack import ApiStack
from stacks.database_stack import DatabaseStack
from config import get_config

app = cdk.App()

# Get environment from context
env_name = app.node.try_get_context("env") or os.getenv("CDK_ENV", "dev")
config = get_config(env_name)

env = cdk.Environment(
    account=config.account_id,
    region=config.region,
)

# Stacks with dependencies
database = DatabaseStack(app, f"{config.prefix}-Database", env=env, config=config)
api = ApiStack(app, f"{config.prefix}-Api", env=env, config=config, tables=database.tables)
api.add_dependency(database)

app.synth()
```

---

## Configuration Pattern

```python
from dataclasses import dataclass
from typing import Dict

@dataclass
class StackConfig:
    env_name: str
    account_id: str
    region: str
    prefix: str

    # Feature flags
    enable_waf: bool = False
    enable_xray: bool = True

    # Sizing
    lambda_memory: int = 256
    lambda_timeout: int = 30

    @property
    def is_production(self) -> bool:
        return self.env_name == "prod"

    def get_tags(self) -> Dict[str, str]:
        return {
            "Environment": self.env_name,
            "Project": self.prefix,
            "ManagedBy": "CDK",
        }

def get_config(env_name: str) -> StackConfig:
    configs = {
        "dev": StackConfig(
            env_name="dev",
            account_id="123456789012",
            region="us-east-1",
            prefix="MyApp-Dev",
        ),
        "prod": StackConfig(
            env_name="prod",
            account_id="987654321098",
            region="us-east-1",
            prefix="MyApp-Prod",
            enable_waf=True,
        ),
    }
    return configs.get(env_name, configs["dev"])
```

---

## Stack Pattern

```python
from aws_cdk import Stack, RemovalPolicy, aws_dynamodb as dynamodb
from constructs import Construct

class DatabaseStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, config, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Apply tags to all resources
        for key, value in config.get_tags().items():
            cdk.Tags.of(self).add(key, value)

        self.table = dynamodb.Table(
            self, "MainTable",
            table_name=f"{config.prefix}-Main",
            partition_key=dynamodb.Attribute(name="pk", type=dynamodb.AttributeType.STRING),
            sort_key=dynamodb.Attribute(name="sk", type=dynamodb.AttributeType.STRING),
            billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
            removal_policy=RemovalPolicy.RETAIN if config.is_production else RemovalPolicy.DESTROY,
        )
```

---

## Deployment Commands

```bash
# Synthesize CloudFormation
cdk synth

# Show changes before deploying
cdk diff

# Deploy all stacks
cdk deploy --all

# Deploy specific stack with context
cdk deploy ApiStack -c env=staging

# Deploy with profile
cdk deploy --profile staging --all

# Destroy (dev only!)
cdk destroy --all
```

---

## Environment-Based Naming

| Environment | Stack Prefix | Who Deploys |
|-------------|--------------|-------------|
| dev | `App-dev-{username}` | Individual developers |
| staging | `App-staging` | Shared |
| prod | `App-prod` | CI/CD only |

**Resource naming rules:**
- S3 buckets: `{purpose}-{env_name}-{account}`
- Lambda: `{app}-{function}-{env_name}`
- Include `env_name` in all globally-named resources

---

## AWS Well-Architected Principles

Apply these six pillars when designing CDK infrastructure:

| Pillar | CDK Practice |
|--------|--------------|
| **Operational Excellence** | Proper tagging, CloudWatch logging, alarms |
| **Security** | Least-privilege IAM, encryption, Secrets Manager |
| **Reliability** | Multi-AZ where appropriate, health checks |
| **Performance** | Right-size Lambda memory, use caching |
| **Cost Optimization** | Serverless-first, lifecycle policies |
| **Sustainability** | Managed services over self-hosted |

---

## Security Checklist

- [ ] IAM roles with least privilege (no `*` actions)
- [ ] Encryption at rest for databases
- [ ] Use Secrets Manager for sensitive config
- [ ] CORS by environment (never `ALL_ORIGINS` in prod)
- [ ] Set RemovalPolicy (RETAIN for prod, DESTROY for dev)
- [ ] Never hardcode credentials or account IDs
