# Elixir CQRS System Testing Guide

## System Architecture Overview

The system consists of:
- **Command Service**: Handles write operations (port 50051)
- **Query Service**: Handles read operations (port 50052)
- **Client Service**: GraphQL API gateway (port 4000)
- **PostgreSQL**: 3 instances for command, query, and event store
- **Monitoring**: Prometheus, Jaeger, and Grafana

## Current Status

Docker containers are running:
- ✅ PostgreSQL databases (ports 5432, 5433, 5434)
- ✅ Prometheus (port 9090)
- ✅ Jaeger (port 16686)
- ✅ Grafana (port 3000)

Elixir services need to be started manually in separate terminals.

## Quick Test

If all services are running, test with curl:

```bash
# Create a category
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation { createCategory(input: { name: \"Electronics\", description: \"Electronic devices\" }) { id name description } }"}' \
  | jq .

# List categories
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"query { categories { id name description } }"}' \
  | jq .
```

## Known Issues

1. **Warning Messages**: The OpenTelemetry warnings about `tls_certificate_check` are normal and don't affect functionality.

2. **Service Dependencies**: 
   - Command Service and Query Service must be running before Client Service can connect
   - PostgreSQL containers must be healthy before starting Elixir services

3. **Port Conflicts**: Ensure no other services are using:
   - 4000 (GraphQL)
   - 50051 (Command gRPC)
   - 50052 (Query gRPC)

## Complete Test Scenario

1. **Create Category**:
```graphql
mutation {
  createCategory(input: {
    name: "Electronics"
    description: "Electronic devices and accessories"
  }) {
    id
    name
    description
  }
}
```

2. **Update Category**:
```graphql
mutation {
  updateCategory(input: {
    id: "YOUR_CATEGORY_ID"
    name: "Updated Electronics"
    description: "Updated description"
  }) {
    id
    name
    description
  }
}
```

3. **Create Product**:
```graphql
mutation {
  createProduct(input: {
    name: "MacBook Pro"
    categoryId: "YOUR_CATEGORY_ID"
    price: 2499.99
  }) {
    id
    name
    price
    categoryId
  }
}
```

4. **Update Product Price**:
```graphql
mutation {
  updateProductPrice(input: {
    id: "YOUR_PRODUCT_ID"
    newPrice: 2299.99
  }) {
    id
    name
    price
  }
}
```

5. **Query All Data**:
```graphql
query {
  categories {
    id
    name
    description
    products {
      id
      name
      price
    }
  }
  products {
    id
    name
    price
    category {
      id
      name
    }
  }
}
```

## Monitoring

- **Jaeger**: http://localhost:16686 - View distributed traces
- **Prometheus**: http://localhost:9090 - View metrics
- **Grafana**: http://localhost:3000 - View dashboards (default login: admin/admin)