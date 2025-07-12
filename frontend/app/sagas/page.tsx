"use client"

import { useEffect, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

interface Saga {
  id: string
  saga_id: string
  saga_type: string
  aggregate_id: string
  status: string
  current_step: string
  step_data: any
  error_reason?: string
  created_at: string
  updated_at: string
}

export default function SagasPage() {
  const [sagas, setSagas] = useState<Saga[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchSagas = async () => {
      try {
        // TODO: Replace with actual API call
        // For now, using mock data
        setSagas([
          {
            id: "1",
            saga_id: "order-saga-123",
            saga_type: "OrderSaga",
            aggregate_id: "order-456",
            status: "completed",
            current_step: "ConfirmOrder",
            step_data: {},
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
          {
            id: "2",
            saga_id: "order-saga-789",
            saga_type: "OrderSaga",
            aggregate_id: "order-012",
            status: "in_progress",
            current_step: "ProcessPayment",
            step_data: {},
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
        ])
        setLoading(false)
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to fetch sagas")
        setLoading(false)
      }
    }

    fetchSagas()
    const interval = setInterval(fetchSagas, 2000) // Refresh every 2 seconds

    return () => clearInterval(interval)
  }, [])

  const getStatusColor = (status: string) => {
    switch (status) {
      case "completed":
        return "bg-green-500"
      case "failed":
        return "bg-red-500"
      case "compensated":
        return "bg-yellow-500"
      case "in_progress":
        return "bg-blue-500"
      default:
        return "bg-gray-500"
    }
  }

  if (loading) {
    return (
      <div className="container mx-auto p-8">
        <h1 className="text-3xl font-bold mb-6">SAGA Monitor</h1>
        <div className="flex items-center justify-center h-64">
          <div className="text-lg">Loading...</div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container mx-auto p-8">
        <h1 className="text-3xl font-bold mb-6">SAGA Monitor</h1>
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
          Error: {error}
        </div>
      </div>
    )
  }

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-6">SAGA Monitor</h1>

      {/* Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total SAGAs</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{sagas.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">In Progress</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {sagas.filter((s) => s.status === "in_progress").length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Completed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {sagas.filter((s) => s.status === "completed").length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Failed</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              {sagas.filter((s) => s.status === "failed").length}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* SAGA List */}
      <Card>
        <CardHeader>
          <CardTitle>Active SAGAs</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {sagas.map((saga) => (
              <div
                key={saga.id}
                className="border rounded-lg p-4 hover:shadow-md transition-shadow"
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-4">
                    <h3 className="font-semibold">{saga.saga_type}</h3>
                    <Badge className={getStatusColor(saga.status)}>
                      {saga.status}
                    </Badge>
                  </div>
                  <span className="text-sm text-gray-500">
                    {new Date(saga.updated_at).toLocaleTimeString()}
                  </span>
                </div>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-sm">
                  <div>
                    <span className="text-gray-500">SAGA ID:</span>{" "}
                    <span className="font-mono">{saga.saga_id}</span>
                  </div>
                  <div>
                    <span className="text-gray-500">Aggregate:</span>{" "}
                    <span className="font-mono">{saga.aggregate_id}</span>
                  </div>
                  <div>
                    <span className="text-gray-500">Current Step:</span>{" "}
                    <span className="font-semibold">{saga.current_step}</span>
                  </div>
                  <div>
                    <span className="text-gray-500">Created:</span>{" "}
                    {new Date(saga.created_at).toLocaleTimeString()}
                  </div>
                </div>
                {saga.error_reason && (
                  <div className="mt-2 p-2 bg-red-50 rounded text-sm text-red-700">
                    Error: {saga.error_reason}
                  </div>
                )}
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}