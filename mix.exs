defmodule Minarai.MixProject do
  use Mix.Project

  def project do
    [
      app: :minarai,
      version: "0.1.0",
      elixir: "~> 1.7",
      # build_embedded: true,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :wx]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:scenic, "~> 0.10"},
      # {:scenic_driver_glfw, "~> 0.10", targets: :host},
      # {:scenic_driver_glfw, path: "../scenic_driver_glfw", targets: :host},
      # {:minarai_nif, path: "../minarai_nif"},
    ]
  end
end
