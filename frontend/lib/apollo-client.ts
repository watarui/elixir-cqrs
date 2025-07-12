import { ApolloClient, InMemoryCache, createHttpLink, split } from "@apollo/client"
import { getMainDefinition } from "@apollo/client/utilities"
import { GraphQLWsLink } from "@apollo/client/link/subscriptions"
import { createClient } from "graphql-ws"

const httpLink = createHttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT || "http://localhost:4000/graphql",
})

// WebSocket link for subscriptions
const wsLink = typeof window !== "undefined"
  ? new GraphQLWsLink(
      createClient({
        url: process.env.NEXT_PUBLIC_WS_ENDPOINT || "ws://localhost:4000/graphql",
      })
    )
  : null

// Split based on operation type
const splitLink = typeof window !== "undefined" && wsLink
  ? split(
      ({ query }) => {
        const definition = getMainDefinition(query)
        return (
          definition.kind === "OperationDefinition" &&
          definition.operation === "subscription"
        )
      },
      wsLink,
      httpLink
    )
  : httpLink

export const apolloClient = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache(),
  defaultOptions: {
    watchQuery: {
      fetchPolicy: "cache-and-network",
    },
  },
})