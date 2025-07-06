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
      extra_applications: [:logger]
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
      {:decimal, "~> 2.0"}
    ]
  end
end
