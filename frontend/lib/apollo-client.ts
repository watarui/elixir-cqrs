import { ApolloClient, InMemoryCache, createHttpLink, split } from "@apollo/client"
import { getMainDefinition } from "@apollo/client/utilities"
import { GraphQLWsLink } from "@apollo/client/link/subscriptions"
import { createClient } from "graphql-ws"
import { config } from "./config"

const httpLink = createHttpLink({
  uri: config.graphql.httpEndpoint,
})

// WebSocket link for subscriptions
const wsLink = typeof window !== "undefined"
  ? new GraphQLWsLink(
      createClient({
        url: config.graphql.wsEndpoint,
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