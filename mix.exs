defmodule ExoRedis.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exo_redis,
      version: "0.1.0",
      elixir: "~> 1.5",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ranch],
      mod: {ExoRedis.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ranch, "~> 1.5", override: true},
      {:bitmap, "~> 1.0.1"},
      {:merkle_patricia_tree, "~> 0.2.6"},
      {:zset, "~> 0.1.0"},
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:distillery, "~> 1.5", runtime: false},
      {:exprof, "~> 0.2.3", runtime: false},
      {:benchee, "~> 0.13.0", runtime: false},
      {:benchwarmer, "~> 0.0.2", runtime: false}
    ]
  end
end
