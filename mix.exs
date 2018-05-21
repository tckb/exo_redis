defmodule ExoRedis.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exo_redis,
      version: "0.1.2",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ranch],
      mod: {ExoRedis.Application, []}
    ]
  end

  defp deps do
    [
      {:ranch, "~> 1.5", override: true},
      {:bitmap, "~> 1.0.1"},
      {:zset, "~> 0.1.0"},
      {:xxhash, "~> 0.2.0", hex: :erlang_xxhash},
      {:distillery, "~> 1.5", runtime: false},
      {:exprof, "~> 0.2.3", runtime: false},
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:benchee, "~> 0.13.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end
end
