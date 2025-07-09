#!/bin/bash

# Start all services for the Elixir CQRS application

echo "Starting all services..."

# Kill existing services
echo "Stopping existing services..."
pkill -f "beam.smp.*mix run --no-halt" || true
pkill -f "beam.smp.*mix phx.server" || true
sleep 2

# Start Command Service
echo "Starting Command Service on port 50051..."
cd /Users/w/w/elixir-cqrs/apps/command_service
mix grpc.server &
command_service_pid=$!
echo "Command Service PID: $command_service_pid"

# Wait for Command Service to start
sleep 5

# Start Query Service (if not already running)
echo "Checking Query Service..."
if ! lsof -i :50052 > /dev/null 2>&1; then
    echo "Starting Query Service on port 50052..."
    cd /Users/w/w/elixir-cqrs/apps/query_service
    mix run --no-halt &
    query_service_pid=$!
    echo "Query Service PID: $query_service_pid"
else
    echo "Query Service already running on port 50052"
fi

# Wait for services to be ready
sleep 5

# Start Client Service (if not already running)
echo "Checking Client Service..."
if ! lsof -i :4000 > /dev/null 2>&1; then
    echo "Starting Client Service on port 4000..."
    cd /Users/w/w/elixir-cqrs/apps/client_service
    mix phx.server &
    client_service_pid=$!
    echo "Client Service PID: $client_service_pid"
else
    echo "Client Service already running on port 4000"
fi

# Wait for all services to start
sleep 5

echo ""
echo "All services started:"
echo "- Command Service: http://localhost:50051 (gRPC)"
echo "- Query Service: http://localhost:50052 (gRPC)"
echo "- Client Service: http://localhost:4000 (GraphQL)"
echo ""
echo "GraphQL Playground: http://localhost:4000/graphql"
echo ""
echo "To stop all services, run: pkill -f beam.smp"