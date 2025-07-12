/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  env: {
    GRAPHQL_ENDPOINT: process.env.GRAPHQL_ENDPOINT || 'http://localhost:4000/graphql',
    EVENT_STORE_DB_URL: process.env.EVENT_STORE_DB_URL || 'postgresql://postgres:postgres@localhost:5432/elixir_cqrs_event_store_dev',
    COMMAND_DB_URL: process.env.COMMAND_DB_URL || 'postgresql://postgres:postgres@localhost:5433/elixir_cqrs_command_dev',
    QUERY_DB_URL: process.env.QUERY_DB_URL || 'postgresql://postgres:postgres@localhost:5434/elixir_cqrs_query_dev',
  },
}

module.exports = nextConfig