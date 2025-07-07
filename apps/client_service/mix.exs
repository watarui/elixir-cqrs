defmodule ClientService.MixProject do
  use Mix.Project

  def project do
    [
      app: :client_service,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ClientService.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # 共有ライブラリ
      {:shared, in_umbrella: true},

      # Web フレームワーク
      {:phoenix, "~> 1.7.0"},
      {:plug_cowboy, "~> 2.5"},
      {:corsica, "~> 2.0"},

      # GraphQL
      {:absinthe, "~> 1.7"},
      {:absinthe_phoenix, "~> 2.0"},
      {:absinthe_plug, "~> 1.5"},
      {:dataloader, "~> 2.0"},

      # gRPC クライアント
      {:grpc, "~> 0.10.0"},
      {:protobuf, "~> 0.14.0"},
      {:protobuf_generate, "~> 0.1.0"},

      # JSON
      {:jason, "~> 1.0"},

      # ユーティリティ
      {:uuid, "~> 1.1"},

      # OpenTelemetry Phoenix instrumentation
      {:opentelemetry_phoenix, "~> 1.1"},
      {:opentelemetry_absinthe, "~> 1.0"},

      # Prometheus メトリクス
      {:telemetry_metrics_prometheus, "~> 1.1"},

      # 開発・テスト
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:stream_data, "~> 0.6", only: :test}
    ]
  end
end
