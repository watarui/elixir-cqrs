#!/bin/bash

# Start all services for the Elixir CQRS system

echo "Starting Elixir CQRS System..."

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    
    if lsof -i :$port > /dev/null 2>&1; then
        echo "✓ $service_name is running on port $port"
        return 0
    else
        echo "✗ $service_name is not running on port $port"
        return 1
    fi
}

# Kill existing services
echo "Stopping any existing services..."
pkill -f "beam.*command_service" || true
pkill -f "beam.*query_service" || true
pkill -f "beam.*client_service" || true
sleep 2

# Start Docker containers
echo "Starting Docker containers..."
docker compose up -d

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL databases to be ready..."
sleep 5

# Start Command Service
echo "Starting Command Service..."
cd apps/command_service
nohup iex -S mix > ../../logs/command_service.log 2>&1 &
cd ../..
sleep 5

# Start Query Service
echo "Starting Query Service..."
cd apps/query_service
nohup iex -S mix > ../../logs/query_service.log 2>&1 &
cd ../..
sleep 5

# Start Client Service
echo "Starting Client Service..."
cd apps/client_service
nohup mix phx.server > ../../logs/client_service.log 2>&1 &
cd ../..
sleep 5

# Check services
echo ""
echo "Checking services status..."
check_service "Command Service (gRPC)" 50051
check_service "Query Service (gRPC)" 50052
check_service "Client Service (GraphQL)" 4000
check_service "PostgreSQL Command" 5433
check_service "PostgreSQL Query" 5434
check_service "PostgreSQL Event Store" 5435
check_service "Prometheus" 9090
check_service "Jaeger" 16686
check_service "Grafana" 3000

echo ""
echo "All services started!"
echo ""
echo "Access points:"
echo "- GraphQL Playground: http://localhost:4000/graphql"
echo "- Jaeger UI: http://localhost:16686"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000"
echo ""
echo "Logs are available in the logs/ directory"