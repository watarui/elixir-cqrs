// 環境変数の設定を一元管理
export const config = {
  // GraphQL エンドポイント
  graphql: {
    httpEndpoint: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT || 'http://localhost:4000/graphql',
    wsEndpoint: process.env.NEXT_PUBLIC_WS_ENDPOINT || 'ws://localhost:4000/socket/websocket',
  },
  
  // メトリクスエンドポイント
  metrics: {
    endpoint: process.env.NEXT_PUBLIC_METRICS_ENDPOINT || 'http://localhost:4000/metrics',
  },
  
  // 外部サービス
  external: {
    jaeger: process.env.NEXT_PUBLIC_JAEGER_URL || 'http://localhost:16686',
    prometheus: process.env.NEXT_PUBLIC_PROMETHEUS_URL || 'http://localhost:9090',
    grafana: process.env.NEXT_PUBLIC_GRAFANA_URL || 'http://localhost:3000',
  },
  
  // データベース表示用 URL (pgweb)
  databases: {
    eventStore: 'http://localhost:5050',
    commandDb: 'http://localhost:5051',
    queryDb: 'http://localhost:5052',
  },
  
  // その他の設定
  polling: {
    defaultInterval: 5000, // 5秒
    metricsInterval: 10000, // 10秒
  },
}