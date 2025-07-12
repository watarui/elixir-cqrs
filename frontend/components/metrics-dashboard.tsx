"use client"

import React from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { LineChart, Line, AreaChart, Area, BarChart, Bar, ResponsiveContainer, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts'
import { Activity, TrendingUp, TrendingDown, Minus, Cpu, HardDrive, Clock, AlertTriangle } from 'lucide-react'
import { motion } from 'framer-motion'

interface MetricData {
  time: string
  value: number
}

interface SystemMetrics {
  cpu: number
  memory: number
  latency: number
  throughput: number
  errorRate: number
  activeConnections: number
  history: {
    throughput: MetricData[]
    latency: MetricData[]
    errorRate: MetricData[]
  }
}

// Tailwind が動的クラス名をサポートしないため、静的なマップを使用
const colorStyles = {
  blue: {
    background: "bg-blue-100 dark:bg-blue-900/20",
    text: "text-blue-600 dark:text-blue-400",
    chart: "#3b82f6"
  },
  green: {
    background: "bg-green-100 dark:bg-green-900/20",
    text: "text-green-600 dark:text-green-400",
    chart: "#10b981"
  },
  purple: {
    background: "bg-purple-100 dark:bg-purple-900/20",
    text: "text-purple-600 dark:text-purple-400",
    chart: "#8b5cf6"
  },
  orange: {
    background: "bg-orange-100 dark:bg-orange-900/20",
    text: "text-orange-600 dark:text-orange-400",
    chart: "#f59e0b"
  },
  red: {
    background: "bg-red-100 dark:bg-red-900/20",
    text: "text-red-600 dark:text-red-400",
    chart: "#ef4444"
  },
  indigo: {
    background: "bg-indigo-100 dark:bg-indigo-900/20",
    text: "text-indigo-600 dark:text-indigo-400",
    chart: "#6366f1"
  }
}

type ColorType = keyof typeof colorStyles

const MetricCard = ({ 
  title, 
  value, 
  unit, 
  trend, 
  icon, 
  color = "blue",
  sparklineData 
}: { 
  title: string
  value: number | string
  unit?: string
  trend?: number
  icon: React.ReactNode
  color?: ColorType
  sparklineData?: MetricData[]
}) => {
  const getTrendIcon = () => {
    if (!trend) return <Minus className="w-4 h-4" />
    if (trend > 0) return <TrendingUp className="w-4 h-4" />
    return <TrendingDown className="w-4 h-4" />
  }

  const getTrendColor = () => {
    if (!trend) return "text-gray-500"
    if (title.includes("Error") || title.includes("Latency")) {
      return trend > 0 ? "text-red-500" : "text-green-500"
    }
    return trend > 0 ? "text-green-500" : "text-red-500"
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
    >
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium flex items-center justify-between">
            <span className="flex items-center gap-2">
              <div className={`p-1.5 rounded-lg ${colorStyles[color].background} ${colorStyles[color].text}`}>
                {icon}
              </div>
              {title}
            </span>
            {trend !== undefined && (
              <span className={`flex items-center gap-1 text-xs ${getTrendColor()}`}>
                {getTrendIcon()}
                {Math.abs(trend)}%
              </span>
            )}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {value}
            {unit && <span className="text-sm font-normal text-muted-foreground ml-1">{unit}</span>}
          </div>
          {sparklineData && sparklineData.length > 0 && (
            <div className="h-12 mt-3">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={sparklineData}>
                  <Line 
                    type="monotone" 
                    dataKey="value" 
                    stroke={colorStyles[color].chart}
                    strokeWidth={2}
                    dot={false}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}
        </CardContent>
      </Card>
    </motion.div>
  )
}

export function MetricsDashboard({ metrics }: { metrics?: SystemMetrics }) {
  const defaultMetrics: SystemMetrics = {
    cpu: 45,
    memory: 62,
    latency: 23,
    throughput: 1250,
    errorRate: 0.2,
    activeConnections: 89,
    history: {
      throughput: Array.from({ length: 20 }, (_, i) => ({
        time: `${i}`,
        value: 1000 + Math.random() * 500,
      })),
      latency: Array.from({ length: 20 }, (_, i) => ({
        time: `${i}`,
        value: 20 + Math.random() * 10,
      })),
      errorRate: Array.from({ length: 20 }, (_, i) => ({
        time: `${i}`,
        value: Math.random() * 2,
      })),
    },
  }

  const data = metrics || defaultMetrics

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        <MetricCard
          title="CPU Usage"
          value={`${data.cpu}%`}
          trend={-5}
          icon={<Cpu className="w-4 h-4" />}
          color="blue" as ColorType
        />
        <MetricCard
          title="Memory"
          value={`${data.memory}%`}
          trend={2}
          icon={<HardDrive className="w-4 h-4" />}
          color="green" as ColorType
        />
        <MetricCard
          title="Latency"
          value={data.latency}
          unit="ms"
          trend={-12}
          icon={<Clock className="w-4 h-4" />}
          color="purple" as ColorType
        />
        <MetricCard
          title="Throughput"
          value={data.throughput}
          unit="req/s"
          trend={8}
          icon={<Activity className="w-4 h-4" />}
          color="orange" as ColorType
        />
        <MetricCard
          title="Error Rate"
          value={`${data.errorRate}%`}
          trend={-25}
          icon={<AlertTriangle className="w-4 h-4" />}
          color="red" as ColorType
        />
        <MetricCard
          title="Connections"
          value={data.activeConnections}
          trend={0}
          icon={<Activity className="w-4 h-4" />}
          color="indigo" as ColorType
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Throughput Trend</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={150}>
              <AreaChart data={data.history.throughput}>
                <defs>
                  <linearGradient id="colorThroughput" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.8}/>
                    <stop offset="95%" stopColor="#f59e0b" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="time" className="text-xs" />
                <YAxis className="text-xs" />
                <Tooltip />
                <Area type="monotone" dataKey="value" stroke="#f59e0b" fillOpacity={1} fill="url(#colorThroughput)" />
              </AreaChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Latency Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={150}>
              <LineChart data={data.history.latency}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="time" className="text-xs" />
                <YAxis className="text-xs" />
                <Tooltip />
                <Line type="monotone" dataKey="value" stroke="#8b5cf6" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Error Rate</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={150}>
              <BarChart data={data.history.errorRate}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="time" className="text-xs" />
                <YAxis className="text-xs" />
                <Tooltip />
                <Bar dataKey="value" fill="#ef4444" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}