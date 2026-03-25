---
name: aws-bedrock
description: AWS Bedrock patterns for model invocation, prompt engineering, and AI integration. TRIGGER when code uses boto3 bedrock-runtime, InvokeModel, Converse API, or user asks about Bedrock, Claude on AWS, or AI/ML integration. Do NOT trigger for general Python or non-Bedrock AI work.
---

# AWS Bedrock Patterns

## 1. GovCloud Model Availability

| Model | Model ID | Inference Type | Regions |
|-------|----------|---------------|---------|
| Claude Sonnet 4.5 | `us.anthropic.claude-sonnet-4-5-v1-0` | Cross-Region | us-gov-west-1, us-gov-east-1 |
| Claude 3.5 Sonnet v2 | `us.anthropic.claude-3-5-sonnet-20241022-v2:0` | Cross-Region | us-gov-west-1, us-gov-east-1 |
| Claude 3 Haiku | `anthropic.claude-3-haiku-20240307-v1:0` | On-Demand | us-gov-west-1 |

**Cross-Region Inference** model IDs use the `us.` prefix. Enable Cross-Region Inference in the Bedrock console before use.

**Commercial AWS** models use the same IDs without partition differences, but check region availability.

---

## 2. Bedrock Runtime — Converse API (Preferred)

Always prefer the Converse API over InvokeModel. It is model-agnostic and handles format differences automatically.

```python
import boto3

client = boto3.client("bedrock-runtime", region_name="us-gov-west-1")

def invoke_model(prompt: str, system_prompt: str = "") -> str:
    """Invoke a Bedrock model using the Converse API."""
    messages = [{"role": "user", "content": [{"text": prompt}]}]

    kwargs: dict = {
        "modelId": "us.anthropic.claude-sonnet-4-5-v1-0",
        "messages": messages,
        "inferenceConfig": {
            "maxTokens": 4096,
            "temperature": 0.0,
            "topP": 1.0,
        },
    }
    if system_prompt:
        kwargs["system"] = [{"text": system_prompt}]

    response = client.converse(**kwargs)
    return response["output"]["message"]["content"][0]["text"]
```

### Converse Stream (for streaming responses)

```python
def invoke_model_stream(prompt: str) -> str:
    """Stream a Bedrock model response."""
    response = client.converse_stream(
        modelId="us.anthropic.claude-sonnet-4-5-v1-0",
        messages=[{"role": "user", "content": [{"text": prompt}]}],
        inferenceConfig={"maxTokens": 4096, "temperature": 0.0},
    )

    result = []
    for event in response["stream"]:
        if "contentBlockDelta" in event:
            delta = event["contentBlockDelta"]["delta"]
            if "text" in delta:
                result.append(delta["text"])
    return "".join(result)
```

### Multi-turn Conversations

```python
def converse_multi_turn(conversation: list[dict], system_prompt: str = "") -> dict:
    """Continue a multi-turn conversation. Returns the full updated conversation."""
    kwargs: dict = {
        "modelId": "us.anthropic.claude-sonnet-4-5-v1-0",
        "messages": conversation,
        "inferenceConfig": {"maxTokens": 4096, "temperature": 0.0},
    }
    if system_prompt:
        kwargs["system"] = [{"text": system_prompt}]

    response = client.converse(**kwargs)
    assistant_message = response["output"]["message"]
    conversation.append(assistant_message)
    return conversation
```

### Tool Use via Converse API

```python
tool_config = {
    "tools": [
        {
            "toolSpec": {
                "name": "get_threat_score",
                "description": "Get the threat score for a domain or IP address",
                "inputSchema": {
                    "json": {
                        "type": "object",
                        "properties": {
                            "indicator": {
                                "type": "string",
                                "description": "Domain name or IP address",
                            }
                        },
                        "required": ["indicator"],
                    }
                },
            }
        }
    ]
}

response = client.converse(
    modelId="us.anthropic.claude-sonnet-4-5-v1-0",
    messages=[{"role": "user", "content": [{"text": "Check threat score for 192.168.1.1"}]}],
    toolConfig=tool_config,
    inferenceConfig={"maxTokens": 4096},
)

# Check if model wants to use a tool
stop_reason = response["stopReason"]
if stop_reason == "tool_use":
    tool_use_block = next(
        block for block in response["output"]["message"]["content"]
        if "toolUse" in block
    )
    tool_name = tool_use_block["toolUse"]["name"]
    tool_input = tool_use_block["toolUse"]["input"]
    tool_use_id = tool_use_block["toolUse"]["toolUseId"]

    # Execute the tool, then send result back
    tool_result = execute_tool(tool_name, tool_input)

    messages = [
        {"role": "user", "content": [{"text": "Check threat score for 192.168.1.1"}]},
        response["output"]["message"],
        {
            "role": "user",
            "content": [
                {
                    "toolResult": {
                        "toolUseId": tool_use_id,
                        "content": [{"text": str(tool_result)}],
                    }
                }
            ],
        },
    ]
    final_response = client.converse(
        modelId="us.anthropic.claude-sonnet-4-5-v1-0",
        messages=messages,
        toolConfig=tool_config,
        inferenceConfig={"maxTokens": 4096},
    )
```

---

## 3. InvokeModel (Legacy — Anthropic Native Format)

Use only when Converse API is insufficient (rare). Requires model-specific request/response formatting.

```python
import json

def invoke_model_legacy(prompt: str) -> str:
    """Legacy InvokeModel — prefer Converse API instead."""
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 4096,
        "temperature": 0.0,
        "messages": [{"role": "user", "content": prompt}],
    })
    response = client.invoke_model(
        modelId="us.anthropic.claude-sonnet-4-5-v1-0",
        body=body,
        contentType="application/json",
        accept="application/json",
    )
    return json.loads(response["body"].read())["content"][0]["text"]
```

---

## 4. Graceful Degradation

```python
from botocore.exceptions import ClientError
import time
import logging

logger = logging.getLogger(__name__)

MODEL_CHAIN = [
    "us.anthropic.claude-sonnet-4-5-v1-0",
    "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
    "anthropic.claude-3-haiku-20240307-v1:0",
]

RETRYABLE_ERRORS = {
    "ThrottlingException",
    "ModelTimeoutException",
    "ServiceUnavailableException",
    "ModelNotReadyException",
}


def invoke_with_fallback(
    prompt: str,
    system_prompt: str = "",
    max_retries: int = 2,
) -> tuple[str, str]:
    """Try models in order, with retries. Returns (response_text, model_used)."""
    for model_id in MODEL_CHAIN:
        for attempt in range(max_retries + 1):
            try:
                kwargs: dict = {
                    "modelId": model_id,
                    "messages": [{"role": "user", "content": [{"text": prompt}]}],
                    "inferenceConfig": {"maxTokens": 4096, "temperature": 0.0},
                }
                if system_prompt:
                    kwargs["system"] = [{"text": system_prompt}]

                response = client.converse(**kwargs)
                return response["output"]["message"]["content"][0]["text"], model_id

            except ClientError as e:
                error_code = e.response["Error"]["Code"]
                if error_code in RETRYABLE_ERRORS and attempt < max_retries:
                    wait = 2**attempt
                    logger.warning(
                        "Retryable error %s on %s (attempt %d), waiting %ds",
                        error_code, model_id, attempt + 1, wait,
                    )
                    time.sleep(wait)
                    continue
                logger.warning("Model %s failed: %s, trying next", model_id, error_code)
                break

    raise RuntimeError("All models in fallback chain failed")
```

---

## 5. Prompt Engineering

### Temperature Guide
| Use Case | Temperature | Why |
|----------|------------|-----|
| Classification, extraction | 0.0 | Deterministic, consistent |
| Summarization | 0.0–0.3 | Slight variation OK |
| Analysis, reasoning | 0.0–0.5 | Balance accuracy/creativity |
| Creative writing | 0.7–1.0 | Diversity in output |

### Structured Output (JSON)

```python
system_prompt = """You are a threat analysis engine. Always respond with valid JSON.
Output format:
{
  "threat_level": "low|medium|high|critical",
  "confidence": 0.0-1.0,
  "indicators": ["list of IOCs"],
  "recommendation": "action to take"
}"""

response = client.converse(
    modelId="us.anthropic.claude-sonnet-4-5-v1-0",
    messages=[{"role": "user", "content": [{"text": f"Analyze: {event_data}"}]}],
    system=[{"text": system_prompt}],
    inferenceConfig={"maxTokens": 4096, "temperature": 0.0},
)
```

### System Prompt Best Practices
1. **Role first**: "You are a [specific role] that [specific task]."
2. **Constraints**: "Never include PII. Always respond in JSON."
3. **Output format**: Show the exact schema expected.
4. **Examples**: Include 1-2 few-shot examples for complex tasks.
5. **Guardrails**: "If uncertain, respond with `{"threat_level": "unknown"}`."

---

## 6. CDK Integration

### IAM Policy for Bedrock Access

```python
from aws_cdk import Aws, aws_iam as iam

# Least-privilege Bedrock access
bedrock_policy = iam.PolicyStatement(
    actions=["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
    resources=[
        f"arn:{Aws.PARTITION}:bedrock:{Aws.REGION}::foundation-model/us.anthropic.claude-*",
        f"arn:{Aws.PARTITION}:bedrock:{Aws.REGION}::foundation-model/anthropic.claude-*",
    ],
)
lambda_fn.add_to_role_policy(bedrock_policy)
```

### VPC Endpoint for Bedrock Runtime

```python
from aws_cdk import aws_ec2 as ec2

vpc.add_interface_endpoint(
    "BedrockRuntimeEndpoint",
    service=ec2.InterfaceVpcEndpointAwsService("bedrock-runtime"),
    private_dns_enabled=True,
    subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS),
)
```

### Lambda Environment Variables (never hardcode model IDs)

```python
lambda_fn = lambda_.Function(
    self, "AnalysisHandler",
    runtime=lambda_.Runtime.PYTHON_3_12,
    handler="handler.lambda_handler",
    environment={
        "PRIMARY_MODEL_ID": "us.anthropic.claude-sonnet-4-5-v1-0",
        "FALLBACK_MODEL_ID": "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
        "BEDROCK_REGION": Aws.REGION,
    },
)
```

---

## 7. Cost and Token Management

| Model | Max Input | Max Output | Input $/1M | Output $/1M |
|-------|-----------|------------|-----------|-------------|
| Claude Sonnet 4.5 | 200K | 8192 | $3.00 | $15.00 |
| Claude 3.5 Sonnet v2 | 200K | 8192 | $3.00 | $15.00 |
| Claude 3 Haiku | 200K | 4096 | $0.25 | $1.25 |

### Token Usage Tracking

```python
def invoke_and_track(prompt: str) -> tuple[str, dict]:
    """Invoke model and return response with usage metrics."""
    response = client.converse(
        modelId="us.anthropic.claude-sonnet-4-5-v1-0",
        messages=[{"role": "user", "content": [{"text": prompt}]}],
        inferenceConfig={"maxTokens": 4096},
    )
    usage = response["usage"]
    metrics = {
        "input_tokens": usage["inputTokens"],
        "output_tokens": usage["outputTokens"],
        "total_tokens": usage["totalTokens"],
    }
    return response["output"]["message"]["content"][0]["text"], metrics
```

---

## 8. Testing Patterns

### Mock with botocore Stubber

```python
import pytest
from botocore.stub import Stubber
import boto3


@pytest.fixture
def bedrock_client():
    client = boto3.client("bedrock-runtime", region_name="us-gov-west-1")
    with Stubber(client) as stubber:
        yield client, stubber


def test_converse_api(bedrock_client):
    client, stubber = bedrock_client
    stubber.add_response(
        "converse",
        {
            "output": {
                "message": {
                    "role": "assistant",
                    "content": [{"text": '{"threat_level": "high"}'}],
                }
            },
            "usage": {"inputTokens": 50, "outputTokens": 20, "totalTokens": 70},
            "stopReason": "end_turn",
        },
    )
    stubber.activate()

    response = client.converse(
        modelId="us.anthropic.claude-sonnet-4-5-v1-0",
        messages=[{"role": "user", "content": [{"text": "test"}]}],
        inferenceConfig={"maxTokens": 100},
    )
    assert response["output"]["message"]["content"][0]["text"] == '{"threat_level": "high"}'
```

### Integration Test Marker

```python
@pytest.mark.integration
@pytest.mark.bedrock
def test_real_bedrock_invocation():
    """Requires AWS credentials and Bedrock access. Run with: pytest -m bedrock"""
    client = boto3.client("bedrock-runtime", region_name="us-gov-west-1")
    response = client.converse(
        modelId="us.anthropic.claude-sonnet-4-5-v1-0",
        messages=[{"role": "user", "content": [{"text": "Say 'hello'"}]}],
        inferenceConfig={"maxTokens": 10, "temperature": 0.0},
    )
    assert "hello" in response["output"]["message"]["content"][0]["text"].lower()
```

### conftest.py Fixture

```python
@pytest.fixture
def mock_bedrock_response():
    """Factory fixture for Bedrock Converse API responses."""
    def _make_response(text: str, input_tokens: int = 50, output_tokens: int = 20):
        return {
            "output": {
                "message": {
                    "role": "assistant",
                    "content": [{"text": text}],
                }
            },
            "usage": {
                "inputTokens": input_tokens,
                "outputTokens": output_tokens,
                "totalTokens": input_tokens + output_tokens,
            },
            "stopReason": "end_turn",
        }
    return _make_response
```
