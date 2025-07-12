"use client"

import { useEffect, useState, useRef } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"

interface Message {
  id: string
  topic: string
  payload: any
  timestamp: string
}

interface TopicStats {
  [topic: string]: number
}

const TOPICS = [
  "events:order_created",
  "events:order_updated",
  "events:order_completed",
  "events:payment_processed",
  "events:inventory_reserved",
  "events:inventory_released",
  "events:shipping_scheduled",
  "events:saga_started",
  "events:saga_completed",
  "events:saga_failed",
  "events:saga_compensated",
  ":commands",
  ":queries",
]

export default function PubSubPage() {
  const [messages, setMessages] = useState<Message[]>([])
  const [topicStats, setTopicStats] = useState<TopicStats>({})
  const [selectedTopic, setSelectedTopic] = useState<string>("all")
  const [isConnected, setIsConnected] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    // Simulate WebSocket connection
    const simulateMessages = () => {
      const topics = TOPICS
      const randomTopic = topics[Math.floor(Math.random() * topics.length)]
      
      const newMessage: Message = {
        id: `msg-${Date.now()}-${Math.random()}`,
        topic: randomTopic,
        payload: generateMockPayload(randomTopic),
        timestamp: new Date().toISOString(),
      }

      setMessages((prev) => [...prev.slice(-99), newMessage]) // Keep last 100 messages
      setTopicStats((prev) => ({
        ...prev,
        [randomTopic]: (prev[randomTopic] || 0) + 1,
      }))
    }

    // Simulate connection
    setTimeout(() => setIsConnected(true), 1000)

    // Generate messages at random intervals
    const interval = setInterval(() => {
      if (Math.random() > 0.3) {
        simulateMessages()
      }
    }, 1000)

    return () => {
      clearInterval(interval)
      setIsConnected(false)
    }
  }, [])

  useEffect(() => {
    // Auto-scroll to bottom when new messages arrive
    // Only scroll within the message container, not the entire viewport
    if (messagesEndRef.current) {
      const container = messagesEndRef.current.parentElement
      if (container) {
        container.scrollTop = container.scrollHeight
      }
    }
  }, [messages])

  const generateMockPayload = (topic: string): any => {
    switch (topic) {
      case "events:order_created":
        return {
          order_id: `order-${Math.floor(Math.random() * 1000)}`,
          customer_id: `cust-${Math.floor(Math.random() * 100)}`,
          total_amount: { amount: Math.floor(Math.random() * 10000), currency: "USD" },
        }
      case "events:payment_processed":
        return {
          payment_id: `pay-${Math.floor(Math.random() * 1000)}`,
          order_id: `order-${Math.floor(Math.random() * 1000)}`,
          status: Math.random() > 0.1 ? "success" : "failed",
        }
      case ":commands":
        return {
          command_type: "CreateOrder",
          command_id: `cmd-${Math.floor(Math.random() * 1000)}`,
          correlation_id: `corr-${Math.floor(Math.random() * 1000)}`,
        }
      default:
        return { data: "Event data" }
    }
  }

  const getTopicColor = (topic: string) => {
    if (topic.includes("order")) return "bg-blue-500"
    if (topic.includes("payment")) return "bg-green-500"
    if (topic.includes("inventory")) return "bg-yellow-500"
    if (topic.includes("shipping")) return "bg-purple-500"
    if (topic.includes("saga")) return "bg-red-500"
    if (topic.includes("command")) return "bg-orange-500"
    if (topic.includes("quer")) return "bg-pink-500"
    return "bg-gray-500"
  }

  const filteredMessages =
    selectedTopic === "all"
      ? messages
      : messages.filter((m) => m.topic === selectedTopic)

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-6">PubSub Monitor</h1>

      {/* Connection Status */}
      <div className="mb-6">
        <Badge className={isConnected ? "bg-green-500" : "bg-red-500"}>
          {isConnected ? "Connected" : "Disconnected"}
        </Badge>
      </div>

      {/* Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Total Messages</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{messages.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Active Topics</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{Object.keys(topicStats).length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Messages/Min</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {messages.filter(
                (m) =>
                  new Date(m.timestamp).getTime() > Date.now() - 60000
              ).length}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium">Peak Topic</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-sm font-bold truncate">
              {Object.entries(topicStats).sort((a, b) => b[1] - a[1])[0]?.[0] || "N/A"}
            </div>
          </CardContent>
        </Card>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Topic Statistics */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle>Topic Statistics</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 max-h-[500px] overflow-y-auto">
              {Object.entries(topicStats)
                .sort((a, b) => b[1] - a[1])
                .map(([topic, count]) => (
                  <div
                    key={topic}
                    className="flex items-center justify-between p-2 rounded hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
                    onClick={() => setSelectedTopic(topic)}
                  >
                    <div className="flex items-center space-x-2">
                      <div className={`w-3 h-3 rounded-full ${getTopicColor(topic)}`} />
                      <span className="text-sm font-mono truncate">{topic}</span>
                    </div>
                    <span className="text-sm font-semibold">{count}</span>
                  </div>
                ))}
            </div>
          </CardContent>
        </Card>

        {/* Message Stream */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>Message Stream</CardTitle>
              <select
                value={selectedTopic}
                onChange={(e) => setSelectedTopic(e.target.value)}
                className="text-sm border rounded px-2 py-1"
              >
                <option value="all">All Topics</option>
                {Object.keys(topicStats).map((topic) => (
                  <option key={topic} value={topic}>
                    {topic}
                  </option>
                ))}
              </select>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 max-h-[500px] overflow-y-auto">
              {filteredMessages.map((message) => (
                <div
                  key={message.id}
                  className="border rounded p-3 text-sm hover:shadow-md transition-shadow"
                >
                  <div className="flex items-center justify-between mb-1">
                    <Badge className={getTopicColor(message.topic)}>
                      {message.topic}
                    </Badge>
                    <span className="text-xs text-gray-500">
                      {new Date(message.timestamp).toLocaleTimeString()}
                    </span>
                  </div>
                  <pre className="mt-2 p-2 bg-gray-50 dark:bg-gray-800 rounded text-xs overflow-x-auto">
                    {JSON.stringify(message.payload, null, 2)}
                  </pre>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}