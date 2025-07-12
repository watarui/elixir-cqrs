"use client"

import React, { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Badge } from '@/components/ui/badge'
import { Play, Copy, History, Code, BookOpen, Trash2, Clock, Info, ChevronDown, ChevronRight } from 'lucide-react'
import { motion } from 'framer-motion'
// import CodeEditor from '@/components/code-editor'
import CodeEditor from '@/components/simple-code-editor'

// プリセットクエリの定義（変数とヘルプを含む）
const presetQueries = {
  queries: [
    {
      name: 'Dashboard Stats',
      category: 'monitoring',
      description: 'ダッシュボードの統計情報を取得します',
      query: `query GetDashboardStats {
  dashboardStats {
    eventCount
    commandCount
    queryCount
    categoryCount
    productCount
    orderCount
    activeNodes
    sagaStats {
      active
      completed
      failed
      total
    }
    eventRate
    lastEventTime
  }
}`,
      variables: {}
    },
    {
      name: 'System Statistics',
      category: 'monitoring',
      description: 'システムの詳細統計情報を取得します',
      query: `query GetSystemStatistics {
  systemStatistics {
    eventStore {
      totalRecords
      lastUpdated
    }
    commandDb {
      totalRecords
      lastUpdated
    }
    queryDb {
      categories
      products
      orders
      lastUpdated
    }
    sagas {
      active
      completed
      failed
      total
    }
  }
}`,
      variables: {}
    },
    {
      name: 'Recent Events',
      category: 'monitoring',
      description: '最新のイベントを取得します',
      query: `query GetRecentEvents($limit: Int) {
  recentEvents(limit: $limit) {
    id
    aggregateId
    aggregateType
    eventType
    eventData
    eventVersion
    insertedAt
  }
}`,
      variables: { limit: 10 }
    },
    {
      name: 'List Categories',
      category: 'query',
      description: 'カテゴリ一覧を取得します（ページネーション対応）',
      query: `query ListCategories($limit: Int, $offset: Int, $sortBy: String, $sortOrder: SortOrder) {
  categories(limit: $limit, offset: $offset, sortBy: $sortBy, sortOrder: $sortOrder) {
    id
    name
    description
    active
    productCount
    createdAt
    updatedAt
    products {
      id
      name
      price
      currency
    }
  }
}`,
      variables: { limit: 10, offset: 0, sortBy: "createdAt", sortOrder: "desc" }
    },
    {
      name: 'List Products',
      category: 'query',
      description: '商品一覧を取得します（フィルタ・ページネーション対応）',
      query: `query ListProducts(
  $categoryId: ID
  $limit: Int
  $offset: Int
  $sortBy: String
  $sortOrder: SortOrder
  $minPrice: Decimal
  $maxPrice: Decimal
) {
  products(
    categoryId: $categoryId
    limit: $limit
    offset: $offset
    sortBy: $sortBy
    sortOrder: $sortOrder
    minPrice: $minPrice
    maxPrice: $maxPrice
  ) {
    id
    name
    description
    price
    currency
    active
    categoryId
    category {
      id
      name
    }
    createdAt
    updatedAt
  }
}`,
      variables: { limit: 10, offset: 0, sortBy: "createdAt", sortOrder: "desc" }
    },
    {
      name: 'Get Product by ID',
      category: 'query',
      description: '特定の商品情報を取得します',
      query: `query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    price
    categoryId
    category {
      id
      name
    }
    createdAt
  }
}`,
      variables: {
        id: "product_01J2J8Q5KXH9YNXRK6A1QNWMZF"
      }
    },
    {
      name: 'List Sagas',
      category: 'monitoring',
      description: 'Saga の詳細一覧を取得します',
      query: `query ListSagas($status: String, $sagaType: String, $limit: Int, $offset: Int) {
  sagas(status: $status, sagaType: $sagaType, limit: $limit, offset: $offset) {
    id
    sagaType
    status
    state
    aggregateId
    createdAt
    updatedAt
    completedAt
    failedAt
    errorMessage
  }
}`,
      variables: { limit: 10, offset: 0 }
    },
    {
      name: 'PubSub Stats',
      category: 'monitoring',
      description: 'PubSub トピックの統計情報を取得します',
      query: `query GetPubSubStats {
  pubsubStats {
    topic
    messageCount
    messagesPerMinute
    lastMessageAt
    subscribers
  }
}`,
      variables: {}
    },
    {
      name: 'Query Executions',
      category: 'monitoring',
      description: 'クエリ実行履歴を取得します',
      query: `query GetQueryExecutions($queryType: String, $status: String, $limit: Int) {
  queryExecutions(queryType: $queryType, status: $status, limit: $limit) {
    id
    queryType
    status
    startedAt
    completedAt
    durationMs
    error
  }
}`,
      variables: { limit: 20 }
    },
    {
      name: 'Command Executions',
      category: 'monitoring',
      description: 'コマンド実行履歴を取得します',
      query: `query GetCommandExecutions($commandType: String, $status: String, $limit: Int) {
  commandExecutions(commandType: $commandType, status: $status, limit: $limit) {
    id
    commandType
    status
    startedAt
    completedAt
    durationMs
    error
  }
}`,
      variables: { limit: 20 }
    }
  ],
  mutations: [
    {
      name: 'Create Category',
      category: 'command',
      description: '新しいカテゴリを作成します',
      query: `mutation CreateCategory($name: String!, $description: String) {
  createCategory(input: {
    name: $name
    description: $description
  }) {
    id
    name
    description
    active
    productCount
    createdAt
    updatedAt
  }
}`,
      variables: {
        name: "家電・エレクトロニクス",
        description: "家電製品とアクセサリー"
      }
    },
    {
      name: 'Create Product',
      category: 'command',
      description: '新しい商品を作成します',
      query: `mutation CreateProduct(
  $name: String!,
  $description: String,
  $price: Decimal!,
  $categoryId: ID!
) {
  createProduct(input: {
    name: $name
    description: $description
    price: $price
    categoryId: $categoryId
  }) {
    id
    name
    description
    price
    currency
    categoryId
    active
    createdAt
    updatedAt
  }
}`,
      variables: {
        name: "iPhone 15 Pro",
        description: "最新のAppleスマートフォン（チタニウムデザイン）",
        price: "179800",
        categoryId: "category_01J2J8Q5KXH9YNXRK6A1QNWMZF"
      }
    },
    {
      name: 'Change Product Price',
      category: 'command',
      description: '商品価格を変更します',
      query: `mutation ChangeProductPrice($id: ID!, $newPrice: Decimal!) {
  changeProductPrice(id: $id, newPrice: $newPrice) {
    id
    name
    price
    currency
    updatedAt
  }
}`,
      variables: {
        id: "product_01J2J8Q5KXH9YNXRK6A1QNWMZF",
        newPrice: "149800"
      }
    },
    {
      name: 'Create Order',
      category: 'command',
      description: '新しい注文を作成します（Saga開始）',
      query: `mutation CreateOrder($input: CreateOrderInput!) {
  createOrder(input: $input) {
    id
    userId
    status
    totalAmount
    currency
    items {
      productId
      quantity
      price
    }
    createdAt
  }
}`,
      variables: {
        input: {
          userId: "user_12345",
          items: [
            {
              productId: "product_01J2J8Q5KXH9YNXRK6A1QNWMZF",
              quantity: 1
            }
          ]
        }
      }
    },
    {
      name: 'Delete Product',
      category: 'command',
      description: '商品を削除します',
      query: `mutation DeleteProduct($id: ID!) {
  deleteProduct(input: {
    id: $id
  }) {
    success
    message
  }
}`,
      variables: {
        id: "product_01J2J8Q5KXH9YNXRK6A1QNWMZF"
      }
    }
  ],
  subscriptions: [
    {
      name: 'Event Stream',
      category: 'realtime',
      description: 'リアルタイムイベントストリームを購読します',
      query: `subscription EventStream($aggregateType: String, $eventType: String) {
  eventStream(aggregateType: $aggregateType, eventType: $eventType) {
    id
    aggregateId
    aggregateType
    eventType
    eventData
    eventVersion
    insertedAt
  }
}`,
      variables: {}
    },
    {
      name: 'Dashboard Stats Stream',
      category: 'realtime',
      description: 'ダッシュボード統計のリアルタイム更新を購読します',
      query: `subscription DashboardStatsStream {
  dashboardStatsStream {
    eventCount
    commandCount
    queryCount
    categoryCount
    productCount
    orderCount
    activeNodes
    sagaStats {
      active
      completed
      failed
      total
    }
    eventRate
    lastEventTime
  }
}`,
      variables: {}
    },
    {
      name: 'Saga Updates',
      category: 'realtime',
      description: 'Saga状態のリアルタイム更新を購読します',
      query: `subscription SagaUpdates($sagaType: String) {
  sagaUpdates(sagaType: $sagaType) {
    id
    sagaType
    status
    state
    aggregateId
    updatedAt
    errorMessage
  }
}`,
      variables: {}
    }
  ]
}

export default function GraphQLExplorerPage() {
  const [query, setQuery] = useState('')
  const [variables, setVariables] = useState('{}')
  const [response, setResponse] = useState<any>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [history, setHistory] = useState<Array<{query: string, variables: string, timestamp: Date}>>([])
  const [executionTime, setExecutionTime] = useState<number | null>(null)
  const [selectedPreset, setSelectedPreset] = useState<any>(null)
  const [darkMode, setDarkMode] = useState(true)
  const [expandedHistory, setExpandedHistory] = useState<number | null>(null)

  // 履歴をlocalStorageから読み込み
  useEffect(() => {
    const savedHistory = localStorage.getItem('graphql-explorer-history')
    if (savedHistory) {
      setHistory(JSON.parse(savedHistory).map((item: any) => ({
        ...item,
        timestamp: new Date(item.timestamp)
      })))
    }
  }, [])

  const executeQuery = async () => {
    if (!query.trim()) return

    setLoading(true)
    setError(null)
    const startTime = Date.now()

    try {
      // 変数をパース
      let parsedVariables = {}
      try {
        parsedVariables = JSON.parse(variables)
      } catch (e) {
        setError('変数のJSON形式が正しくありません')
        setLoading(false)
        return
      }

      const response = await fetch('http://localhost:4000/graphql', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          query,
          variables: parsedVariables
        }),
      })

      const contentType = response.headers.get('content-type')
      if (!contentType || !contentType.includes('application/json')) {
        const text = await response.text()
        setError(`エラー: GraphQLエンドポイントからHTMLが返されました。サーバーが正しく起動していることを確認してください。\n\nステータス: ${response.status}\nレスポンス: ${text.substring(0, 200)}...`)
        setResponse(null)
        setLoading(false)
        return
      }

      const data = await response.json()
      setExecutionTime(Date.now() - startTime)
      setResponse(data)

      if (data.errors) {
        setError('GraphQL エラーが発生しました')
      } else {
        // 成功した場合は履歴に追加
        const newHistory = [
          { query, variables, timestamp: new Date() },
          ...history.slice(0, 19) // 最大20件まで保存
        ]
        setHistory(newHistory)
        localStorage.setItem('graphql-explorer-history', JSON.stringify(newHistory))
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'エラーが発生しました')
      setResponse(null)
    } finally {
      setLoading(false)
    }
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
  }

  const clearAll = () => {
    setQuery('')
    setVariables('{}')
    setResponse(null)
    setError(null)
    setExecutionTime(null)
    setSelectedPreset(null)
  }

  const clearHistory = () => {
    setHistory([])
    localStorage.removeItem('graphql-explorer-history')
  }

  const loadPresetQuery = (preset: any) => {
    setQuery(preset.query)
    setVariables(JSON.stringify(preset.variables, null, 2))
    setSelectedPreset(preset)
    setResponse(null)
    setError(null)
  }

  const loadHistoryItem = (item: any) => {
    setQuery(item.query)
    setVariables(item.variables)
    setSelectedPreset(null)
    setResponse(null)
    setError(null)
  }

  const formatJson = (obj: any) => {
    return JSON.stringify(obj, null, 2)
  }

  // ダークモードの初期設定
  useEffect(() => {
    const isDark = document.documentElement.classList.contains('dark')
    setDarkMode(isDark)
  }, [])


  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold flex items-center gap-2">
          <Code className="w-8 h-8" />
          GraphQL Explorer
        </h1>
        <Badge variant="outline" className="text-sm">
          Endpoint: http://localhost:4000/graphql
        </Badge>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* 左側: クエリエディタ */}
        <div className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                <span>クエリエディタ</span>
                <div className="flex gap-2">
                  <Button size="sm" variant="outline" onClick={clearAll}>
                    <Trash2 className="w-4 h-4 mr-1" />
                    クリア
                  </Button>
                  <Button size="sm" onClick={executeQuery} disabled={loading}>
                    <Play className="w-4 h-4 mr-1" />
                    実行
                  </Button>
                </div>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {selectedPreset && (
                <div className="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-md flex items-start gap-2">
                  <Info className="w-5 h-5 text-blue-600 dark:text-blue-400 mt-0.5" />
                  <div className="flex-1">
                    <p className="text-sm font-medium text-blue-900 dark:text-blue-100">
                      {selectedPreset.name}
                    </p>
                    <p className="text-sm text-blue-700 dark:text-blue-300">
                      {selectedPreset.description}
                    </p>
                  </div>
                </div>
              )}
              
              <div>
                <label className="block text-sm font-medium mb-2">Query</label>
                <CodeEditor
                  value={query}
                  onChange={setQuery}
                  language="graphql"
                  placeholder="GraphQLクエリを入力してください..."
                  height="256px"
                  theme={darkMode ? 'dark' : 'light'}
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">Variables (JSON)</label>
                <CodeEditor
                  value={variables}
                  onChange={setVariables}
                  language="json"
                  placeholder='{"id": "123"}'
                  height="128px"
                  theme={darkMode ? 'dark' : 'light'}
                />
              </div>

              {executionTime !== null && (
                <div className="text-sm text-gray-500 flex items-center gap-1">
                  <Clock className="w-3 h-3" />
                  実行時間: {executionTime}ms
                </div>
              )}
            </CardContent>
          </Card>

          {/* プリセットクエリ */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <BookOpen className="w-5 h-5" />
                プリセットクエリ
              </CardTitle>
            </CardHeader>
            <CardContent>
              <Tabs defaultValue="queries" className="w-full">
                <TabsList className="grid w-full grid-cols-3">
                  <TabsTrigger value="queries">Queries</TabsTrigger>
                  <TabsTrigger value="mutations">Mutations</TabsTrigger>
                  <TabsTrigger value="subscriptions">Subscriptions</TabsTrigger>
                </TabsList>
                
                <div className="mt-4">
                  <TabsContent value="queries" className="mt-0">
                    <ScrollArea className="h-48 w-full">
                      <div className="space-y-2">
                        {presetQueries.queries.map((preset, index) => (
                          <Button
                            key={index}
                            variant="outline"
                            size="sm"
                            className="w-full justify-start text-left"
                            onClick={() => loadPresetQuery(preset)}
                          >
                            <div className="flex-1">
                              <span className="font-medium">{preset.name}</span>
                              <p className="text-xs text-gray-500 dark:text-gray-400">
                                {preset.description}
                              </p>
                            </div>
                            <Badge variant="secondary" className="ml-2">
                              {preset.category}
                            </Badge>
                          </Button>
                        ))}
                      </div>
                    </ScrollArea>
                  </TabsContent>
                  
                  <TabsContent value="mutations" className="mt-0">
                    <ScrollArea className="h-48 w-full">
                      <div className="space-y-2">
                        {presetQueries.mutations.map((preset, index) => (
                          <Button
                            key={index}
                            variant="outline"
                            size="sm"
                            className="w-full justify-start text-left"
                            onClick={() => loadPresetQuery(preset)}
                          >
                            <div className="flex-1">
                              <span className="font-medium">{preset.name}</span>
                              <p className="text-xs text-gray-500 dark:text-gray-400">
                                {preset.description}
                              </p>
                            </div>
                            <Badge variant="secondary" className="ml-2">
                              {preset.category}
                            </Badge>
                          </Button>
                        ))}
                      </div>
                    </ScrollArea>
                  </TabsContent>
                  
                  <TabsContent value="subscriptions" className="mt-0">
                    <ScrollArea className="h-48 w-full">
                      <div className="space-y-2">
                        {presetQueries.subscriptions.map((preset, index) => (
                          <Button
                            key={index}
                            variant="outline"
                            size="sm"
                            className="w-full justify-start text-left"
                            onClick={() => loadPresetQuery(preset)}
                          >
                            <div className="flex-1">
                              <span className="font-medium">{preset.name}</span>
                              <p className="text-xs text-gray-500 dark:text-gray-400">
                                {preset.description}
                              </p>
                            </div>
                            <Badge variant="secondary" className="ml-2">
                              {preset.category}
                            </Badge>
                          </Button>
                        ))}
                      </div>
                    </ScrollArea>
                  </TabsContent>
                </div>
              </Tabs>
            </CardContent>
          </Card>
        </div>

        {/* 右側: レスポンスビューア */}
        <div className="space-y-4">
          <Card className="h-[600px]">
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                レスポンス
                {response && (
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => copyToClipboard(formatJson(response))}
                  >
                    <Copy className="w-4 h-4 mr-1" />
                    コピー
                  </Button>
                )}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ScrollArea className="h-[500px]">
                {loading && (
                  <div className="flex items-center justify-center h-full">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
                  </div>
                )}
                {error && (
                  <div className="p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-md">
                    <p className="text-red-600 dark:text-red-400 whitespace-pre-wrap">{error}</p>
                  </div>
                )}
                {response && !loading && (
                  <CodeEditor
                    value={formatJson(response)}
                    onChange={() => {}}
                    language="json"
                    height="450px"
                    readOnly={true}
                    theme={darkMode ? 'dark' : 'light'}
                  />
                )}
                {!response && !loading && !error && (
                  <div className="flex items-center justify-center h-full text-gray-500">
                    クエリを実行してください
                  </div>
                )}
              </ScrollArea>
            </CardContent>
          </Card>

          {/* 実行履歴 */}
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center justify-between">
                <span className="flex items-center gap-2">
                  <History className="w-5 h-5" />
                  実行履歴
                </span>
                <Button size="sm" variant="outline" onClick={clearHistory}>
                  履歴をクリア
                </Button>
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ScrollArea className="h-48">
                {history.length === 0 ? (
                  <p className="text-gray-500 text-center py-4">履歴がありません</p>
                ) : (
                  <div className="space-y-2">
                    {history.map((item, index) => (
                      <motion.div
                        key={index}
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: index * 0.05 }}
                      >
                        <div className="border rounded-md p-2">
                          <div className="flex items-center justify-between">
                            <button
                              onClick={() => setExpandedHistory(expandedHistory === index ? null : index)}
                              className="flex items-center gap-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded px-1 flex-1 text-left"
                            >
                              {expandedHistory === index ? (
                                <ChevronDown className="w-3 h-3" />
                              ) : (
                                <ChevronRight className="w-3 h-3" />
                              )}
                              <div className="flex-1 truncate">
                                <p className="font-mono text-xs truncate">
                                  {item.query.split('\n')[0]}
                                </p>
                                <p className="text-xs text-gray-500">
                                  {item.timestamp.toLocaleString()}
                                </p>
                              </div>
                            </button>
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => loadHistoryItem(item)}
                              className="ml-2"
                            >
                              <Play className="w-3 h-3" />
                            </Button>
                          </div>
                          {expandedHistory === index && (
                            <div className="mt-2 pt-2 border-t">
                              <div className="space-y-2">
                                <div>
                                  <p className="text-xs font-medium text-gray-600 dark:text-gray-400">Query:</p>
                                  <pre className="text-xs bg-gray-50 dark:bg-gray-800 p-2 rounded overflow-x-auto">
                                    {item.query}
                                  </pre>
                                </div>
                                {item.variables !== '{}' && (
                                  <div>
                                    <p className="text-xs font-medium text-gray-600 dark:text-gray-400">Variables:</p>
                                    <pre className="text-xs bg-gray-50 dark:bg-gray-800 p-2 rounded overflow-x-auto">
                                      {item.variables}
                                    </pre>
                                  </div>
                                )}
                              </div>
                            </div>
                          )}
                        </div>
                      </motion.div>
                    ))}
                  </div>
                )}
              </ScrollArea>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}