defmodule Helix.Mixfile do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      aliases: aliases(),
      deps: deps()]
  end

  defp deps do
    [
      {:earmark, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.14", only: :dev},
      {:credo, "~> 0.7", only: [:dev, :test]}]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "helix.seeds"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["compile", "helix.test"]
    ]
  end
end