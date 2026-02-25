---
name: aws-cdk-dynamodb
description: DynamoDB patterns including single table design and query patterns. Use when designing tables, writing queries, or setting up GSIs.
---

# DynamoDB Patterns

## Table Definition in CDK

```python
from aws_cdk import RemovalPolicy, aws_dynamodb as dynamodb

table = dynamodb.Table(
    self, "MainTable",
    table_name=f"{config.prefix}-Main",
    partition_key=dynamodb.Attribute(name="pk", type=dynamodb.AttributeType.STRING),
    sort_key=dynamodb.Attribute(name="sk", type=dynamodb.AttributeType.STRING),
    billing_mode=dynamodb.BillingMode.PAY_PER_REQUEST,
    removal_policy=RemovalPolicy.RETAIN if config.is_production else RemovalPolicy.DESTROY,
    point_in_time_recovery=config.is_production,
    stream=dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,  # For event processing
)

# GSI for email lookups
table.add_global_secondary_index(
    index_name="email-index",
    partition_key=dynamodb.Attribute(name="email", type=dynamodb.AttributeType.STRING),
    projection_type=dynamodb.ProjectionType.ALL,
)

# GSI for date-based queries
table.add_global_secondary_index(
    index_name="gsi1",
    partition_key=dynamodb.Attribute(name="gsi1pk", type=dynamodb.AttributeType.STRING),
    sort_key=dynamodb.Attribute(name="gsi1sk", type=dynamodb.AttributeType.STRING),
    projection_type=dynamodb.ProjectionType.ALL,
)
```

---

## Single Table Design Keys

```python
# User entity
USER_PK = "USER#{user_id}"
USER_SK = "PROFILE"

# User's orders (1:many)
ORDER_PK = "USER#{user_id}"
ORDER_SK = "ORDER#{order_id}"

# Order items (1:many from order)
ORDER_ITEM_PK = "ORDER#{order_id}"
ORDER_ITEM_SK = "ITEM#{item_id}"

# GSI patterns for access patterns
# GSI1: Query orders by date
# GSI1PK = "ORDER", GSI1SK = "{date}#{order_id}"
```

**Key design principles:**
- Partition key = entity type + ID
- Sort key = related entity type + ID (for hierarchies)
- GSIs for alternate access patterns
- Overload keys for multiple entity types

---

## Query Patterns

```python
from boto3.dynamodb.conditions import Key, Attr

# Get user with all orders (1:many)
def get_user_with_orders(user_id: str):
    response = table.query(
        KeyConditionExpression=Key("pk").eq(f"USER#{user_id}"),
    )

    user = None
    orders = []
    for item in response["Items"]:
        if item["sk"] == "PROFILE":
            user = item
        elif item["sk"].startswith("ORDER#"):
            orders.append(item)

    return {"user": user, "orders": orders}


# Query with sort key prefix
def get_active_orders(user_id: str):
    return table.query(
        KeyConditionExpression=(
            Key("pk").eq(f"USER#{user_id}") &
            Key("sk").begins_with("ORDER#")
        ),
        FilterExpression=Attr("status").eq("ACTIVE"),
    )


# Query GSI by date range
def get_orders_by_date(start_date: str, end_date: str):
    return table.query(
        IndexName="gsi1",
        KeyConditionExpression=(
            Key("gsi1pk").eq("ORDER") &
            Key("gsi1sk").between(start_date, end_date)
        ),
    )


# Batch get multiple items
def get_users_batch(user_ids: list[str]):
    keys = [{"pk": f"USER#{uid}", "sk": "PROFILE"} for uid in user_ids]
    response = dynamodb.batch_get_item(
        RequestItems={table.name: {"Keys": keys}}
    )
    return response["Responses"][table.name]
```

---

## Write Patterns

```python
# Conditional write (prevent overwrites)
def create_user(user_id: str, email: str):
    try:
        table.put_item(
            Item={
                "pk": f"USER#{user_id}",
                "sk": "PROFILE",
                "email": email,
                "created_at": datetime.utcnow().isoformat(),
            },
            ConditionExpression="attribute_not_exists(pk)",
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise ValueError("User already exists")
        raise


# Update with condition
def update_order_status(user_id: str, order_id: str, new_status: str):
    table.update_item(
        Key={"pk": f"USER#{user_id}", "sk": f"ORDER#{order_id}"},
        UpdateExpression="SET #status = :new_status, updated_at = :now",
        ConditionExpression="#status <> :new_status",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":new_status": new_status,
            ":now": datetime.utcnow().isoformat(),
        },
    )


# Transactional write (all or nothing)
def create_order_with_items(user_id: str, order: dict, items: list[dict]):
    order_id = str(uuid.uuid4())

    transact_items = [
        {
            "Put": {
                "TableName": table.name,
                "Item": {
                    "pk": f"USER#{user_id}",
                    "sk": f"ORDER#{order_id}",
                    **order,
                },
            }
        }
    ]

    for item in items:
        transact_items.append({
            "Put": {
                "TableName": table.name,
                "Item": {
                    "pk": f"ORDER#{order_id}",
                    "sk": f"ITEM#{item['item_id']}",
                    **item,
                },
            }
        })

    dynamodb.transact_write_items(TransactItems=transact_items)
    return order_id
```

---

## Pagination

```python
def list_all_orders(user_id: str):
    """Paginate through all orders."""
    orders = []
    last_key = None

    while True:
        kwargs = {
            "KeyConditionExpression": Key("pk").eq(f"USER#{user_id}") & Key("sk").begins_with("ORDER#"),
            "Limit": 100,
        }
        if last_key:
            kwargs["ExclusiveStartKey"] = last_key

        response = table.query(**kwargs)
        orders.extend(response["Items"])

        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break

    return orders
```

---

## Best Practices

1. **Avoid scans** - Always use queries with partition key
2. **Design for access patterns** - Know your queries before designing
3. **Use sparse indexes** - GSI only indexes items with the GSI key
4. **Batch operations** - Use batch_get/batch_write for multiple items
5. **Transactions** - Use for multi-item atomic operations
6. **TTL** - Set expiration for temporary data
7. **On-demand billing** - Start with PAY_PER_REQUEST, switch to provisioned when patterns are known
