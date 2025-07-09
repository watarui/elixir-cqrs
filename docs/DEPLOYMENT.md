# デプロイメントガイド

## 本番環境へのデプロイ

### 前提条件

- Kubernetes クラスター または Docker Swarm
- PostgreSQL 16+ (高可用性構成推奨)
- SSL/TLS 証明書
- ドメイン名

### ビルド

#### リリースビルド

```bash
# 各サービスのリリースビルド
MIX_ENV=prod mix release

# Docker イメージのビルド
docker build -f Dockerfile.command -t myapp/command-service:latest .
docker build -f Dockerfile.query -t myapp/query-service:latest .
docker build -f Dockerfile.client -t myapp/client-service:latest .
```

#### マルチステージ Dockerfile の例

```dockerfile
# Dockerfile.command
FROM elixir:1.18-alpine AS build

# 依存関係のインストール
RUN apk add --no-cache build-base git

WORKDIR /app

# 依存関係のキャッシュ
COPY mix.exs mix.lock ./
COPY apps/command_service/mix.exs apps/command_service/
COPY apps/shared/mix.exs apps/shared/
RUN mix deps.get --only prod
RUN mix deps.compile

# アプリケーションのビルド
COPY . .
RUN MIX_ENV=prod mix release command_service

# 実行用イメージ
FROM alpine:3.18

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

COPY --from=build /app/_build/prod/rel/command_service ./

ENV HOME=/app

CMD ["bin/command_service", "start"]
```

### 環境設定

#### 環境変数

```bash
# データベース設定
DATABASE_URL=ecto://user:pass@host/db
EVENT_STORE_URL=ecto://user:pass@host/event_store
QUERY_DB_URL=ecto://user:pass@host/query_db

# サービス設定
GRPC_COMMAND_PORT=50051
GRPC_QUERY_PORT=50052
PHX_HOST=example.com
SECRET_KEY_BASE=your-secret-key-base

# 監視設定
OTLP_ENDPOINT=http://otel-collector:4318
JAEGER_ENDPOINT=http://jaeger:14268/api/traces
```

#### Kubernetes 設定例

```yaml
# command-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: command-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: command-service
  template:
    metadata:
      labels:
        app: command-service
    spec:
      containers:
      - name: command-service
        image: myapp/command-service:latest
        ports:
        - containerPort: 50051
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: command-db-url
        - name: EVENT_STORE_URL
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: event-store-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          grpc:
            port: 50051
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          grpc:
            port: 50051
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: command-service
spec:
  selector:
    app: command-service
  ports:
  - port: 50051
    targetPort: 50051
  type: ClusterIP
```

### データベース設定

#### PostgreSQL 高可用性構成

```yaml
# postgres-ha.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-cluster
spec:
  instances: 3
  primaryUpdateStrategy: unsupervised
  
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      
  bootstrap:
    initdb:
      database: event_store
      owner: app_user
      
  storage:
    size: 10Gi
    storageClass: fast-ssd
```

### 監視設定

#### Prometheus 設定

```yaml
# prometheus-config.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'elixir-services'
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app]
      regex: (command|query|client)-service
      action: keep
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      target_label: __address__
      regex: (.+)
      replacement: $1:${__meta_kubernetes_pod_annotation_prometheus_io_port}
```

#### Grafana ダッシュボード

```json
{
  "dashboard": {
    "title": "Elixir CQRS Services",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(phoenix_http_requests_total[5m])"
          }
        ]
      },
      {
        "title": "Command Processing Time",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(command_processing_duration_bucket[5m]))"
          }
        ]
      }
    ]
  }
}
```

### セキュリティ設定

#### TLS/SSL 設定

```elixir
# config/prod.exs
config :client_service, ClientServiceWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ]

# gRPC TLS 設定
config :grpc, start_server: true,
  cred: {:tls, 
    keyfile: System.get_env("GRPC_KEY_PATH"),
    certfile: System.get_env("GRPC_CERT_PATH")
  }
```

#### ネットワークポリシー

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: service-communication
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 50051
    - protocol: TCP
      port: 50052
```

### CI/CD パイプライン

#### GitHub Actions の例

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.18'
        otp-version: '26'
    
    - name: Run tests
      run: |
        mix deps.get
        mix test
    
    - name: Build Docker images
      run: |
        docker build -f Dockerfile.command -t ${{ secrets.REGISTRY }}/command-service:${{ github.ref_name }} .
        docker build -f Dockerfile.query -t ${{ secrets.REGISTRY }}/query-service:${{ github.ref_name }} .
        docker build -f Dockerfile.client -t ${{ secrets.REGISTRY }}/client-service:${{ github.ref_name }} .
    
    - name: Push to registry
      run: |
        echo ${{ secrets.REGISTRY_PASSWORD }} | docker login -u ${{ secrets.REGISTRY_USERNAME }} --password-stdin
        docker push ${{ secrets.REGISTRY }}/command-service:${{ github.ref_name }}
        docker push ${{ secrets.REGISTRY }}/query-service:${{ github.ref_name }}
        docker push ${{ secrets.REGISTRY }}/client-service:${{ github.ref_name }}
    
    - name: Deploy to Kubernetes
      run: |
        kubectl set image deployment/command-service command-service=${{ secrets.REGISTRY }}/command-service:${{ github.ref_name }}
        kubectl set image deployment/query-service query-service=${{ secrets.REGISTRY }}/query-service:${{ github.ref_name }}
        kubectl set image deployment/client-service client-service=${{ secrets.REGISTRY }}/client-service:${{ github.ref_name }}
```

### スケーリング戦略

#### 水平スケーリング

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: command-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: command-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

#### データベーススケーリング

- Event Store: Write-heavy なので、書き込み性能重視
- Query DB: Read レプリカを増やして読み取り性能向上
- Connection Pooling: PgBouncer の使用を推奨

### バックアップとリストア

```bash
# イベントストアのバックアップ
pg_dump -h $EVENT_STORE_HOST -U $DB_USER -d event_store > event_store_backup.sql

# スナップショットによるバックアップ
kubectl exec -it postgres-0 -- pg_basebackup -D /backup -Ft -z -P

# リストア
psql -h $EVENT_STORE_HOST -U $DB_USER -d event_store < event_store_backup.sql
```

### ヘルスチェック

```elixir
# lib/health_check.ex
defmodule HealthCheck do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/health" do
    health_status = %{
      status: "healthy",
      services: %{
        database: check_database(),
        grpc: check_grpc(),
        event_store: check_event_store()
      }
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(health_status))
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1") do
      {:ok, _} -> "healthy"
      _ -> "unhealthy"
    end
  end
end
```

### トラブルシューティング

本番環境での問題については [Troubleshooting Guide](./TROUBLESHOOTING.md) も参照してください。