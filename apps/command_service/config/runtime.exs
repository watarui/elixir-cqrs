import Config

# runtime.exs is executed for all environments, including development.
# It is executed after compilation and before the system starts.
if database_url = System.get_env("DATABASE_URL") do
  config :command_service, CommandService.Infrastructure.Database.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: [:inet6]
end