---
name: aws-cdk-lambda
description: Lambda function patterns with AWS Lambda Powertools. Use when writing Lambda handlers, configuring functions, or setting up API Gateway integrations.
---

# AWS Lambda Patterns

## Lambda Naming (CRITICAL)

**NEVER use explicit `function_name` in CDK Lambda definitions.**

```python
# BAD - causes CloudFormation replacement failures
handler = lambda_.Function(
    self, "UsersHandler",
    function_name=f"{config.prefix}-UsersHandler",  # DON'T DO THIS
    ...
)

# GOOD - let CDK auto-generate the name
handler = lambda_.Function(
    self, "UsersHandler",
    # No function_name - CDK generates it from construct ID
    ...
)
```

**Why:** CloudFormation cannot replace custom-named resources. When a Lambda needs replacement (runtime upgrade, Docker image change, etc.), CloudFormation tries to create the new one before deleting the old one - but the name is taken. This causes `UPDATE_FAILED` and requires manual stack destruction.

**Tradeoff:** Auto-generated names are less readable in AWS Console, but you can:
- Use tags for identification
- Reference the construct ID in logs
- Use CloudWatch log group names (which CAN be explicit)

---

## Lambda in CDK

```python
from aws_cdk import Duration, aws_lambda as lambda_, aws_logs as logs
from constructs import Construct

# Shared layer for common code
shared_layer = lambda_.LayerVersion(
    self, "SharedLayer",
    code=lambda_.Code.from_asset("src/shared"),
    compatible_runtimes=[lambda_.Runtime.PYTHON_3_12],
    description="Shared utilities and models",
)

# Lambda function with best practices
# NOTE: No explicit function_name - CDK auto-generates to allow replacements
handler = lambda_.Function(
    self, "UsersHandler",
    runtime=lambda_.Runtime.PYTHON_3_12,
    handler="api.users.handler",
    code=lambda_.Code.from_asset("src/handlers"),
    memory_size=config.lambda_memory,
    timeout=Duration.seconds(config.lambda_timeout),
    layers=[shared_layer],
    environment={
        "TABLE_NAME": table.table_name,
        "LOG_LEVEL": "DEBUG" if not config.is_production else "INFO",
    },
    tracing=lambda_.Tracing.ACTIVE if config.enable_xray else lambda_.Tracing.DISABLED,
    log_retention=logs.RetentionDays.ONE_WEEK,
)

# Grant permissions (least privilege)
table.grant_read_write_data(handler)
```

---

## API Handler with Powertools

```python
"""Users API handler."""
import os
from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.event_handler import APIGatewayRestResolver
from aws_lambda_powertools.utilities.typing import LambdaContext
import boto3

# Initialize outside handler for connection reuse
logger = Logger()
tracer = Tracer()
app = APIGatewayRestResolver()

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


@app.get("/users")
@tracer.capture_method
def list_users():
    """List all users."""
    response = table.scan(Limit=100)
    return {"users": response.get("Items", [])}


@app.get("/users/<user_id>")
@tracer.capture_method
def get_user(user_id: str):
    """Get user by ID."""
    response = table.get_item(Key={"pk": f"USER#{user_id}", "sk": "PROFILE"})
    if "Item" not in response:
        return {"error": "User not found"}, 404
    return {"user": response["Item"]}


@app.post("/users")
@tracer.capture_method
def create_user():
    """Create a new user."""
    body = app.current_event.json_body
    if not body.get("email"):
        return {"error": "Email is required"}, 400

    user_id = str(uuid.uuid4())
    item = {
        "pk": f"USER#{user_id}",
        "sk": "PROFILE",
        "email": body["email"],
        "name": body.get("name", ""),
        "created_at": datetime.utcnow().isoformat(),
    }
    table.put_item(Item=item)
    return {"user": item}, 201


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event: dict, context: LambdaContext) -> dict:
    """Lambda entry point."""
    return app.resolve(event, context)
```

---

## DynamoDB Stream Processor

```python
"""DynamoDB stream processor."""
from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.utilities.batch import BatchProcessor, EventType
from aws_lambda_powertools.utilities.data_classes.dynamo_db_stream_event import (
    DynamoDBRecord,
)

logger = Logger()
tracer = Tracer()
processor = BatchProcessor(event_type=EventType.DynamoDBStreams)


@tracer.capture_method
def process_record(record: DynamoDBRecord):
    """Process a single stream record."""
    if record.event_name == "INSERT":
        logger.info("New item", extra={"keys": record.dynamodb.keys})
    elif record.event_name == "MODIFY":
        logger.info("Item modified", extra={"keys": record.dynamodb.keys})
    elif record.event_name == "REMOVE":
        logger.info("Item deleted", extra={"keys": record.dynamodb.keys})


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event: dict, context):
    """Lambda entry point."""
    batch = processor.process(event, process_record)
    return processor.response()
```

---

## API Gateway Integration

```python
from aws_cdk import aws_apigateway as apigw

api = apigw.RestApi(
    self, "Api",
    rest_api_name=f"{config.prefix}-API",
    deploy_options=apigw.StageOptions(
        stage_name=config.env_name,
        throttling_rate_limit=1000,
        throttling_burst_limit=500,
    ),
)

# Routes
users = api.root.add_resource("users")
users.add_method("GET", apigw.LambdaIntegration(handler))
users.add_method("POST", apigw.LambdaIntegration(handler))

user = users.add_resource("{userId}")
user.add_method("GET", apigw.LambdaIntegration(handler))
user.add_method("PUT", apigw.LambdaIntegration(handler))
```

---

## Cold Start Optimization

1. **Initialize outside handler** - boto3 clients, DB connections
2. **Use Lambda layers** - Shared code loads once
3. **Minimize package size** - Only required dependencies
4. **Use Provisioned Concurrency** - For latency-critical functions
5. **ARM64 runtime** - Often faster and cheaper

```python
# Good: Initialize outside handler
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

def handler(event, context):
    # table is already initialized
    return table.get_item(Key={"pk": "..."})
```

---

## Error Handling Pattern

```python
from aws_lambda_powertools.utilities.typing import LambdaContext

class AppError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code

@app.exception_handler(AppError)
def handle_app_error(ex: AppError):
    return {"error": ex.message}, ex.status_code

@app.exception_handler(Exception)
def handle_unknown_error(ex: Exception):
    logger.exception("Unhandled error")
    return {"error": "Internal server error"}, 500
```
