---
name: aws-cdk-patterns
description: CDK L3 constructs, modular patterns, and refactoring safety. Use when creating reusable constructs, refactoring stacks, or reorganizing CDK code.
---

# AWS CDK Patterns & Refactoring

## L3 Constructs - Recommended Pattern

Group related resources into reusable constructs:

```python
from aws_cdk import Duration, aws_lambda as lambda_, aws_apigateway as apigw, aws_logs as logs
from constructs import Construct

class ApiEndpoint(Construct):
    """Encapsulates Lambda + API Gateway resource + method."""

    def __init__(
        self,
        scope: Construct,
        id: str,
        *,
        api: apigw.RestApi,
        path: str,
        handler_path: str,
        env_name: str,
        method: str = "POST",
        memory_size: int = 256,
        timeout_seconds: int = 30,
        environment: dict[str, str] | None = None,
    ) -> None:
        super().__init__(scope, id)

        self.log_group = logs.LogGroup(
            self, "LogGroup",
            log_group_name=f"/aws/lambda/{id.lower()}-{env_name}",
            retention=logs.RetentionDays.ONE_WEEK,
        )

        self.function = lambda_.Function(
            self, "Handler",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="index.handler",
            code=lambda_.Code.from_asset(handler_path),
            memory_size=memory_size,
            timeout=Duration.seconds(timeout_seconds),
            environment=environment or {},
            log_group=self.log_group,
        )

        resource = api.root.add_resource(path)
        resource.add_method(method, apigw.LambdaIntegration(self.function, proxy=True))
```

**Usage:**
```python
self.extract = ApiEndpoint(
    self, "Extract",
    api=self.api,
    path="extract",
    handler_path="infrastructure/lambdas/extract",
    env_name=env_name,
    memory_size=512,
)
bucket.grant_read(self.extract.function)
```

---

## CRITICAL: CloudFormation Logical ID Preservation

**When refactoring CDK code (moving resources into constructs), you MUST check for logical ID changes.**

### The Problem

CloudFormation tracks resources by **logical ID** (derived from CDK construct path). When you:
- Move a resource into a construct
- Rename a construct ID
- Change resource nesting

...the logical ID changes, and CloudFormation sees "delete old + create new" - causing deployment failures for explicitly-named resources.

### Detection: ALWAYS Run `cdk diff` First

```bash
# Before refactoring
cdk synth MyStack > before.yaml

# After refactoring
cdk diff MyStack

# WARNING signs - resources being replaced:
# [-] AWS::Lambda::Function OldLogicalId (orphan)
# [+] AWS::Lambda::Function NewLogicalId
```

**If you see `[-]` and `[+]` pairs for the same resource type, STOP and fix logical IDs.**

### Example: What Goes Wrong

```python
# BEFORE (directly in stack):
self.extract_function = lambda_.Function(self, "ExtractFunction", ...)
# Path: Stack/ExtractFunction → Logical ID: ExtractFunctionABC123

# AFTER (in construct):
extract = ApiEndpoint(self, "Extract", ...)
# Path: Stack/Extract/Handler → Logical ID: ExtractHandlerXYZ789  <-- DIFFERENT!
```

### Solution: Override Logical IDs

```python
class ApiEndpoint(Construct):
    def __init__(self, scope, id, *, original_function_id: str = None, ...):
        super().__init__(scope, id)

        self.function = lambda_.Function(self, "Handler", ...)

        # Preserve original CloudFormation logical ID
        if original_function_id:
            cfn_function = self.function.node.default_child
            cfn_function.override_logical_id(original_function_id)
```

**Usage:**
```python
# Find original IDs from CloudFormation console or cdk synth
extract = ApiEndpoint(
    self, "Extract",
    original_function_id="ExtractFunctionABC123",  # From deployed stack
    ...
)
```

### Finding Original Logical IDs

```bash
# From AWS CLI
aws cloudformation describe-stack-resources --stack-name MyStack \
  --query 'StackResources[?ResourceType==`AWS::Lambda::Function`].[LogicalResourceId,PhysicalResourceId]'

# From CloudFormation Console: Stack → Resources tab
```

### Pre-Refactoring Checklist

1. **Run `cdk diff`** against deployed stack
2. **Check for orphaned/replaced resources**
3. **Document original logical IDs** before changing
4. **Use `override_logical_id()`** when moving resources
5. **Test on dev/staging first**

### Recovery: When Deployment Fails

**For staging/dev:**
```bash
cdk destroy MyStack -c env=staging
aws logs delete-log-group --log-group-name /aws/lambda/my-function-staging
cdk deploy MyStack -c env=staging
```

**For production:** Use `override_logical_id()` to match existing resources.

---

## Domain-Driven Constructs

For larger APIs, group by business domain:

```
infrastructure/constructs/
├── documents/           # Document domain
│   ├── extract_api.py
│   └── upload_api.py
├── auth/                # Auth domain
│   └── cognito_api.py
└── shared/
    └── cors.py
```

---

## Anti-Patterns to Avoid

- **Monolithic stack**: All resources in one 500+ line file
- **Shared IAM roles**: Single role for all Lambdas
- **Copy-paste endpoints**: Duplicate Lambda/method code
- **Hardcoded configuration**: Environment values scattered
- **Ignoring `cdk diff`**: Refactoring without checking for replacements
