# Elixir CQRS/ES with Monitor Dashboard

A comprehensive example of CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns implemented in Elixir, featuring a modern monitoring dashboard built with Next.js.

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd elixir-cqrs

# Start everything with demo data
./scripts/start_all.sh --with-frontend --with-demo-data
```

For detailed setup instructions, see [SETUP.md](SETUP.md).

## 📋 Prerequisites

- Elixir 1.15+
- Docker & Docker Compose
- PostgreSQL client tools
- Bun or Node.js (for frontend)

## 🏦 Architecture

This project demonstrates:
- **CQRS Pattern**: Separate command and query models
- **Event Sourcing**: Store all changes as immutable events
- **SAGA Pattern**: Manage distributed transactions
- **GraphQL API**: Unified API gateway
- **Real-time Monitoring**: Live dashboard for system observability

## 🌐 Access URLs

| Service | URL | Description |
|---------|-----|------|
| GraphQL Playground | http://localhost:4000/graphiql | Interactive GraphQL API |
| Monitor Dashboard | http://localhost:4001 | Real-time system monitoring |
| Jaeger UI | http://localhost:16686 | Distributed tracing |
| Prometheus | http://localhost:9090 | Metrics collection |
| Grafana | http://localhost:3000 | Metrics visualization |
| pgAdmin | http://localhost:5050 | Database management |

## 📚 Documentation

- [📖 Setup Guide](SETUP.md) - Detailed setup instructions
- [🏗️ Architecture](docs/ARCHITECTURE.md) - System design and patterns
- [📦 CQRS Pattern](docs/CQRS.md) - Command and Query separation
- [🎭 SAGA Pattern](docs/SAGA.md) - Distributed transaction management
- [📡 Events](docs/EVENTS.md) - Event catalog and schemas
- [🌐 GraphQL API](docs/API_GRAPHQL.md) - API documentation
- [🗄️ pgAdmin Usage](docs/PGADMIN_USAGE.md) - Database management guide

## 🛠️ Development

### Start Services

```bash
# Start all services
./scripts/start_all.sh --with-frontend

# Start only infrastructure
./scripts/setup_infra.sh

# Start only backend
./scripts/start_services.sh

# Start only frontend
cd frontend && bun run dev
```

### Useful Commands

```bash
# Health check
./scripts/check_health.sh

# Stop all services
./scripts/stop_all.sh

# View logs
tail -f logs/*.log

# Run tests
mix test
```

## 📦 Project Structure

```
elixir-cqrs/
├── apps/
│   ├── client_service/     # GraphQL API Gateway
│   ├── command_service/    # Write model & Command handlers
│   ├── query_service/      # Read model & Query handlers
│   └── shared/            # Event Store, SAGA, Common modules
├── frontend/              # Next.js Monitor Dashboard
├── scripts/               # Development scripts
├── k8s/                   # Kubernetes manifests
└── docker-compose.yml     # Docker configuration
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License.

---

[docs/](./docs/)
