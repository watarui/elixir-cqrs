defmodule ElixirCqrs.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      # Umbrella project設定
      umbrella: true,
      elixir: "~> 1.14"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {QueryService.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # gRPC
      {:grpc, "~> 0.10"},
      {:protobuf, "~> 0.14"},
      {:protobuf_generate, "~> 0.1.1"},
      {:cowlib, "~> 2.12", override: true},
      {:gun, "~> 2.0", override: true},

      # Database
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},

      # JSON
      {:jason, "~> 1.2"},

      # Test factories and data generation
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.17", only: :test},

      # Development and test
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp releases do
    [
      client_service: [
        applications: [client_service: :permanent],
        include_executables_for: [:unix],
        steps: [:assemble, :tar]
      ],
      command_service: [
        applications: [command_service: :permanent],
        include_executables_for: [:unix],
        steps: [:assemble, :tar]
      ],
      query_service: [
        applications: [query_service: :permanent],
        include_executables_for: [:unix],
        steps: [:assemble, :tar]
      ]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      # 開発環境セットアップ
      setup: ["deps.get", "cmd mix deps.get", "cmd mix ecto.setup"],

      # テスト実行
      test: ["cmd mix test"],

      # コード品質チェック
      quality: ["format", "credo --strict", "dialyzer"],

      # 全サービス起動
      "start.all": [
        "cmd --app command_service mix run --no-halt",
        "cmd --app query_service mix run --no-halt",
        "cmd --app client_service mix phx.server"
      ],

      # 全データベースのセットアップ
      "ecto.setup": [
        "cmd --app command_service mix ecto.setup",
        "cmd --app query_service mix ecto.setup"
      ],
      "ecto.reset": [
        "cmd --app command_service mix ecto.reset",
        "cmd --app query_service mix ecto.reset"
      ]
    ]
  end
end
