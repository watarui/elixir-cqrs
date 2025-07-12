"use client"

import { useState } from 'react'
import { useQuery } from '@apollo/client'
import { PROMETHEUS_METRICS } from '@/lib/graphql/queries/metrics'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { EnhancedMetricsDashboard } from '@/components/enhanced-metrics-dashboard'
import { Search, Filter, Download, ExternalLink } from 'lucide-react'
import Link from 'next/link'

export default function MetricsPage() {
  const [filter, setFilter] = useState('')
  const [showRawMetrics, setShowRawMetrics] = useState(false)

  const { data, loading, error } = useQuery(PROMETHEUS_METRICS, {
    variables: filter ? { filter: { namePattern: filter } } : {},
    pollInterval: 10000
  })

  const filteredMetrics = data?.prometheusMetrics || []

  return (
    <div className="container mx-auto p-4 lg:p-8 space-y-6">
      {/* ヘッダー */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">System Metrics</h1>
          <p className="text-muted-foreground mt-1">
            Real-time monitoring with Prometheus metrics
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Link href="http://localhost:4000/metrics" target="_blank" rel="noopener noreferrer">
            <Button variant="outline" size="sm">
              <ExternalLink className="w-4 h-4 mr-2" />
              Raw Metrics
            </Button>
          </Link>
          <Link href="http://localhost:16686" target="_blank" rel="noopener noreferrer">
            <Button variant="outline" size="sm">
              <ExternalLink className="w-4 h-4 mr-2" />
              Jaeger
            </Button>
          </Link>
        </div>
      </div>

      {/* メトリクスダッシュボード */}
      <EnhancedMetricsDashboard />

      {/* Raw メトリクス検索 */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Prometheus Metrics Explorer</CardTitle>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setShowRawMetrics(!showRawMetrics)}
            >
              {showRawMetrics ? 'Hide' : 'Show'} Raw Metrics
            </Button>
          </div>
        </CardHeader>
        {showRawMetrics && (
          <CardContent>
            <div className="flex items-center gap-2 mb-4">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground w-4 h-4" />
                <Input
                  placeholder="Filter metrics by name (regex supported)..."
                  value={filter}
                  onChange={(e) => setFilter(e.target.value)}
                  className="pl-10"
                />
              </div>
              <Badge variant="outline">
                {filteredMetrics.length} metrics
              </Badge>
            </div>

            {loading ? (
              <div className="text-center py-8">Loading metrics...</div>
            ) : error ? (
              <div className="text-red-500">Error loading metrics: {error.message}</div>
            ) : (
              <div className="space-y-4 max-h-96 overflow-y-auto">
                {filteredMetrics.map((metric: any) => (
                  <MetricItem key={`${metric.name}-${JSON.stringify(metric.labels)}`} metric={metric} />
                ))}
              </div>
            )}
          </CardContent>
        )}
      </Card>

      {/* メトリクス情報 */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <InfoCard
          title="Collection Interval"
          value="15s"
          description="Metrics are collected every 15 seconds"
        />
        <InfoCard
          title="Retention Period"
          value="7 days"
          description="Historical data is retained for 7 days"
        />
        <InfoCard
          title="Export Format"
          value="Prometheus"
          description="Compatible with Prometheus and Grafana"
        />
      </div>
    </div>
  )
}

function MetricItem({ metric }: { metric: any }) {
  const getTypeColor = (type: string) => {
    switch (type) {
      case 'counter': return 'bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400'
      case 'gauge': return 'bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400'
      case 'histogram': return 'bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400'
      case 'summary': return 'bg-orange-100 text-orange-800 dark:bg-orange-900/20 dark:text-orange-400'
      default: return 'bg-gray-100 text-gray-800 dark:bg-gray-900/20 dark:text-gray-400'
    }
  }

  return (
    <div className="border rounded-lg p-4 hover:bg-muted/50 transition-colors">
      <div className="flex items-start justify-between mb-2">
        <div className="flex-1">
          <h4 className="font-medium text-sm break-all">{metric.name}</h4>
          {metric.help && (
            <p className="text-xs text-muted-foreground mt-1">{metric.help}</p>
          )}
        </div>
        <Badge className={`ml-2 ${getTypeColor(metric.type)}`}>
          {metric.type}
        </Badge>
      </div>
      
      {metric.labels && metric.labels.length > 0 && (
        <div className="flex flex-wrap gap-1 mb-2">
          {metric.labels.map((label: any, i: number) => (
            <Badge key={i} variant="outline" className="text-xs">
              {label.name}="{label.value}"
            </Badge>
          ))}
        </div>
      )}
      
      <div className="text-lg font-mono">
        {metric.value?.toFixed(2) || 0}
      </div>
    </div>
  )
}

function InfoCard({ title, value, description }: any) {
  return (
    <Card>
      <CardContent className="p-6">
        <h3 className="text-sm font-medium text-muted-foreground">{title}</h3>
        <p className="text-2xl font-bold mt-2">{value}</p>
        <p className="text-sm text-muted-foreground mt-1">{description}</p>
      </CardContent>
    </Card>
  )
}