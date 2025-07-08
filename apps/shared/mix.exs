defmodule Shared.MixProject do
  use Mix.Project

  def project do
    [
      app: :shared,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      protobuf: [
        generate: [
          input_path: "proto",
          output_path: "lib/proto"
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Shared.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # gRPC とProtocol Buffers（共通）
      {:grpc, "~> 0.10.0"},
      {:protobuf, "~> 0.14.0"},
      {:protobuf_generate, "~> 0.1.0"},

      # JSON（共通）
      {:jason, "~> 1.0"},

      # Decimal（共通）
      {:decimal, "~> 2.0"},

      # PostgreSQL（イベントストア用）
      {:postgrex, "~> 0.19"},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},

      # OpenTelemetry
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.6"},

      # Telemetry
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.0"},

      # 構造化ログ
      {:logger_json, "~> 5.1"},

      # UUID生成
      {:uuid, "~> 1.1"}
    ]
  end
end
