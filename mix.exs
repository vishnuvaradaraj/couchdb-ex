defmodule CouchDBEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :couchdb_ex,
      version: "0.2.1",
      elixir: "~> 1.6",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.travis": :test]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger,
        :httpoison
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.8.2"},
      {:poison, "~> 3.1.0"},

      {:dialyxir, "~> 1.2.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.29.0 ", only: :dev, runtime: false},
      {:credo, "~> 1.6.7", only: :dev},

      {:excoveralls, "~> 0.15.0", only: :test, runtime: false}
    ]
  end

  defp package do
    [
      description: "A supposed-to-be-good CouchDB interface for elixir",
      maintainers: ["vaartis"],
      licenses: ["BSD-2-Clause"],
      links: %{
        "GitHub" => "https://github.com/vaartis/couchdb-ex"
      }
    ]
  end

end
