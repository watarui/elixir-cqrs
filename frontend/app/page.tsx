export default function Home() {
  return (
    <main className="container mx-auto p-8">
      <h1 className="text-4xl font-bold mb-8">Dashboard Overview</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <DashboardCard
          title="SAGA Monitor"
          description="Track SAGA execution status and compensations"
          href="/sagas"
          color="bg-blue-500"
        />
        <DashboardCard
          title="Event Store"
          description="View event history and stream data"
          href="/events"
          color="bg-green-500"
        />
        <DashboardCard
          title="PubSub Monitor"
          description="Real-time message flow visualization"
          href="/pubsub"
          color="bg-purple-500"
        />
        <DashboardCard
          title="Command History"
          description="Analyze command execution patterns"
          href="/commands"
          color="bg-orange-500"
        />
        <DashboardCard
          title="Query Analytics"
          description="Monitor query performance and patterns"
          href="/queries"
          color="bg-pink-500"
        />
        <DashboardCard
          title="System Topology"
          description="Visualize service dependencies"
          href="/topology"
          color="bg-indigo-500"
        />
      </div>
    </main>
  )
}

function DashboardCard({
  title,
  description,
  href,
  color,
}: {
  title: string
  description: string
  href: string
  color: string
}) {
  return (
    <a
      href={href}
      className="block p-6 bg-white dark:bg-gray-800 rounded-lg shadow-lg hover:shadow-xl transition-shadow"
    >
      <div className={`w-12 h-12 ${color} rounded-lg mb-4`} />
      <h2 className="text-2xl font-semibold mb-2">{title}</h2>
      <p className="text-gray-600 dark:text-gray-400">{description}</p>
    </a>
  )
}