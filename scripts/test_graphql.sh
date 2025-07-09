#!/bin/bash

# Test GraphQL queries and mutations

echo "Testing GraphQL API..."
echo ""

# Create Category
echo "1. Creating category..."
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"Electronics\", description: \"Electronic devices\" }) { id name description } }"
  }' | jq .

echo ""

# List Categories
echo "2. Listing categories..."
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { categories { id name description } }"
  }' | jq .

echo ""

# Create Product (will need to use the category ID from above)
echo "3. Creating product..."
echo "Note: You'll need to replace CATEGORY_ID with the actual ID from the category created above"
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createProduct(input: { name: \"Laptop\", categoryId: \"CATEGORY_ID\", price: 999.99 }) { id name price categoryId } }"
  }' | jq .

echo ""

# List Products
echo "4. Listing products..."
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { products { id name price categoryId } }"
  }' | jq .