use Mix.Config

config :helix, Helix.Process.Repo,
  priv: "priv/repo/process",
  size: 4,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  types: HELL.PostgrexTypes

import_config "#{Mix.env}.exs"
