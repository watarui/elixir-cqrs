"use client"

import React, { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useQuery, useSubscription } from '@apollo/client'
import { METRICS_OVERVIEW, METRICS_STREAM_SUBSCRIPTION, METRIC_TIME_SERIES } from '@/lib/graphql/queries/metrics'
import { MetricsDashboard } from './metrics-dashboard'
import { LineChart, Line, AreaChart, Area, BarChart, Bar, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from 'recharts'
import { Activity, Cpu, HardDrive, Clock, AlertTriangle, GitBranch, Database, Zap, RefreshCw, Download } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

export function EnhancedMetricsDashboard() {
  const [selectedMetrics, setSelectedMetrics] = useState<string[]>([
    'http_request_duration_seconds',
    'commands_total',
    'events_published_total'
  ])
  const [timeRange, setTimeRange] = useState(3600) // 1 hour

  // メトリクス概要を取得
  const { data: overviewData, loading: overviewLoading } = useQuery(METRICS_OVERVIEW, {
    pollInterval: 5000
  })

  // リアルタイムメトリクスをサブスクライブ
  const { data: streamData } = useSubscription(METRICS_STREAM_SUBSCRIPTION)

  // 時系列データを取得
  const { data: timeSeriesData, refetch: refetchTimeSeries } = useQuery(METRIC_TIME_SERIES, {
    variables: { metricNames: selectedMetrics, duration: timeRange },
    pollInterval: 10000
  })

  const metrics = streamData?.metricsStream || overviewData?.metricsOverview

  // 従来のメトリクスダッシュボード用のデータを準備
  const systemMetrics = metrics ? {
    cpu: metrics.system.cpuUsage,
    memory: metrics.system.memoryUsage,
    latency: metrics.application.httpRequestDurationP50,
    throughput: metrics.cqrs.commandsPerSecond * 100,
    errorRate: metrics.application.errorRate * 100,
    activeConnections: metrics.application.activeConnections,
    history: {
      throughput: timeSeriesData?.metricSeries.find(s => s.metricName.includes('commands'))?.values || [],
      latency: timeSeriesData?.metricSeries.find(s => s.metricName.includes('duration'))?.values || [],
      errorRate: timeSeriesData?.metricSeries.find(s => s.metricName.includes('error'))?.values || []
    }
  } : undefined

  const downloadMetrics = () => {
    // CSV 形式でメトリクスをダウンロード
    const csv = generateCSV(metrics)
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `metrics-${new Date().toISOString()}.csv`
    a.click()
  }

  if (overviewLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="w-8 h-8 animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold">System Metrics</h2>
        <div className="flex items-center gap-2">
          <Badge variant={metrics?.system.cpuUsage > 80 ? 'destructive' : 'default'}>
            {metrics?.system.cpuUsage > 80 ? 'High Load' : 'Normal'}
          </Badge>
          <Button onClick={() => refetchTimeSeries()} variant="outline" size="sm">
            <RefreshCw className="w-4 h-4 mr-2" />
            Refresh
          </Button>
          <Button onClick={downloadMetrics} variant="outline" size="sm">
            <Download className="w-4 h-4 mr-2" />
            Export
          </Button>
        </div>
      </div>

      {/* 既存のメトリクスダッシュボード */}
      <MetricsDashboard metrics={systemMetrics} />

      {/* 詳細メトリクス */}
      <Tabs defaultValue="cqrs" className="w-full">
        <TabsList className="grid w-full grid-cols-4">
          <TabsTrigger value="cqrs">CQRS</TabsTrigger>
          <TabsTrigger value="saga">Saga</TabsTrigger>
          <TabsTrigger value="performance">Performance</TabsTrigger>
          <TabsTrigger value="system">System</TabsTrigger>
        </TabsList>

        <TabsContent value="cqrs" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <MetricPanel
              title="Command Processing"
              icon={<Zap className="w-5 h-5" />}
              metrics={[
                { label: "Total Commands", value: metrics?.cqrs.commandsTotal || 0 },
                { label: "Commands/sec", value: `${metrics?.cqrs.commandsPerSecond.toFixed(2)}` || "0" },
                { label: "Error Rate", value: `${(metrics?.cqrs.commandErrorRate * 100).toFixed(2)}%` || "0%" }
              ]}
            />
            <MetricPanel
              title="Event Processing"
              icon={<Activity className="w-5 h-5" />}
              metrics={[
                { label: "Total Events", value: metrics?.cqrs.eventsTotal || 0 },
                { label: "Events/sec", value: `${metrics?.cqrs.eventsPerSecond.toFixed(2)}` || "0" },
                { label: "Total Queries", value: metrics?.cqrs.queriesTotal || 0 }
              ]}
            />
          </div>

          {/* CQRS 時系列グラフ */}
          <Card>
            <CardHeader>
              <CardTitle>Command & Event Throughput</CardTitle>
            </CardHeader>
            <CardContent>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={timeSeriesData?.metricSeries[1]?.values || []}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="timestamp" />
                  <YAxis />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="value" stroke="#8884d8" name="Commands" />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="saga" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard
              title="Active Sagas"
              value={metrics?.saga.activeSagas || 0}
              icon={<GitBranch className="w-5 h-5" />}
              color="blue"
            />
            <StatCard
              title="Completed"
              value={metrics?.saga.completedSagas || 0}
              icon={<GitBranch className="w-5 h-5" />}
              color="green"
            />
            <StatCard
              title="Failed"
              value={metrics?.saga.failedSagas || 0}
              icon={<GitBranch className="w-5 h-5" />}
              color="red"
            />
            <StatCard
              title="Compensated"
              value={metrics?.saga.compensatedSagas || 0}
              icon={<GitBranch className="w-5 h-5" />}
              color="yellow"
            />
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Saga Duration Percentiles</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <PercentileBar
                  label="P50"
                  value={metrics?.saga.sagaDurationP50 || 0}
                  max={10}
                  unit="s"
                />
                <PercentileBar
                  label="P95"
                  value={metrics?.saga.sagaDurationP95 || 0}
                  max={30}
                  unit="s"
                />
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="performance" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">HTTP Request Latency</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <LatencyMetric label="P50" value={metrics?.application.httpRequestDurationP50} />
                  <LatencyMetric label="P95" value={metrics?.application.httpRequestDurationP95} />
                  <LatencyMetric label="P99" value={metrics?.application.httpRequestDurationP99} />
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Throughput</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">
                  {metrics?.application.httpRequestsTotal || 0}
                </div>
                <p className="text-sm text-muted-foreground">Total Requests</p>
                <div className="mt-4">
                  <div className="text-lg">
                    {metrics?.application.activeConnections || 0}
                  </div>
                  <p className="text-sm text-muted-foreground">Active Connections</p>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Error Analysis</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold text-red-600">
                  {(metrics?.application.errorRate * 100).toFixed(2)}%
                </div>
                <p className="text-sm text-muted-foreground">Error Rate</p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="system" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Card>
              <CardHeader>
                <CardTitle>System Resources</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <ResourceBar
                    label="CPU Usage"
                    value={metrics?.system.cpuUsage || 0}
                    icon={<Cpu className="w-4 h-4" />}
                  />
                  <ResourceBar
                    label="Memory Usage"
                    value={metrics?.system.memoryUsage || 0}
                    icon={<HardDrive className="w-4 h-4" />}
                  />
                  <ResourceBar
                    label="Disk Usage"
                    value={metrics?.system.diskUsage || 0}
                    icon={<Database className="w-4 h-4" />}
                  />
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Process Information</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <span className="text-sm text-muted-foreground">Processes</span>
                    <span className="font-medium">{metrics?.system.processCount || 0}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-muted-foreground">Threads</span>
                    <span className="font-medium">{metrics?.system.threadCount || 0}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-muted-foreground">Network In</span>
                    <span className="font-medium">
                      {formatBytes(metrics?.system.networkIo?.bytesIn || 0)}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-muted-foreground">Network Out</span>
                    <span className="font-medium">
                      {formatBytes(metrics?.system.networkIo?.bytesOut || 0)}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}

// ヘルパーコンポーネント

function MetricPanel({ title, icon, metrics }: any) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-sm">
          {icon}
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {metrics.map((metric: any, i: number) => (
            <div key={i} className="flex justify-between">
              <span className="text-sm text-muted-foreground">{metric.label}</span>
              <span className="font-medium">{metric.value}</span>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

function StatCard({ title, value, icon, color }: any) {
  const colorClasses = {
    blue: "bg-blue-100 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400",
    green: "bg-green-100 text-green-600 dark:bg-green-900/20 dark:text-green-400",
    red: "bg-red-100 text-red-600 dark:bg-red-900/20 dark:text-red-400",
    yellow: "bg-yellow-100 text-yellow-600 dark:bg-yellow-900/20 dark:text-yellow-400"
  }

  return (
    <Card>
      <CardContent className="p-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-muted-foreground">{title}</p>
            <p className="text-2xl font-bold">{value}</p>
          </div>
          <div className={`p-3 rounded-lg ${colorClasses[color]}`}>
            {icon}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

function PercentileBar({ label, value, max, unit }: any) {
  const percentage = (value / max) * 100
  return (
    <div>
      <div className="flex justify-between mb-1">
        <span className="text-sm text-muted-foreground">{label}</span>
        <span className="text-sm font-medium">{value.toFixed(2)}{unit}</span>
      </div>
      <div className="w-full bg-gray-200 rounded-full h-2 dark:bg-gray-700">
        <div 
          className="bg-primary h-2 rounded-full transition-all"
          style={{ width: `${Math.min(percentage, 100)}%` }}
        />
      </div>
    </div>
  )
}

function LatencyMetric({ label, value }: any) {
  const getColor = () => {
    if (value < 100) return "text-green-600"
    if (value < 500) return "text-yellow-600"
    return "text-red-600"
  }

  return (
    <div className="flex justify-between">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className={`font-medium ${getColor()}`}>{value?.toFixed(0) || 0}ms</span>
    </div>
  )
}

function ResourceBar({ label, value, icon }: any) {
  const getColor = () => {
    if (value < 50) return "bg-green-500"
    if (value < 80) return "bg-yellow-500"
    return "bg-red-500"
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center gap-2">
          {icon}
          <span className="text-sm font-medium">{label}</span>
        </div>
        <span className="text-sm font-medium">{value.toFixed(1)}%</span>
      </div>
      <div className="w-full bg-gray-200 rounded-full h-2 dark:bg-gray-700">
        <motion.div
          className={`h-2 rounded-full ${getColor()}`}
          initial={{ width: 0 }}
          animate={{ width: `${value}%` }}
          transition={{ duration: 0.5 }}
        />
      </div>
    </div>
  )
}

// ユーティリティ関数

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`
}

function generateCSV(metrics: any): string {
  if (!metrics) return ''
  
  const rows = [
    ['Metric', 'Value', 'Timestamp'],
    ['CPU Usage', metrics.system.cpuUsage, metrics.timestamp],
    ['Memory Usage', metrics.system.memoryUsage, metrics.timestamp],
    ['HTTP Requests Total', metrics.application.httpRequestsTotal, metrics.timestamp],
    ['Error Rate', metrics.application.errorRate, metrics.timestamp],
    ['Commands/sec', metrics.cqrs.commandsPerSecond, metrics.timestamp],
    ['Events/sec', metrics.cqrs.eventsPerSecond, metrics.timestamp],
    ['Active Sagas', metrics.saga.activeSagas, metrics.timestamp]
  ]
  
  return rows.map(row => row.join(',')).join('\n')
}