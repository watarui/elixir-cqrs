#!/bin/bash

# Script to setup databases and run migrations

set -e

echo "Setting up databases..."

# Create databases
echo "Creating databases..."
mix ecto.create

# Run migrations for each app
echo "Running migrations for shared app..."
cd apps/shared && mix ecto.migrate && cd ../..

echo "Running migrations for command_service..."
cd apps/command_service && mix ecto.migrate && cd ../..

echo "Running migrations for query_service..."
cd apps/query_service && mix ecto.migrate && cd ../..

echo "Database setup completed!"