Application.ensure_all_started(:db_connection)
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:shared)

ExUnit.start()
