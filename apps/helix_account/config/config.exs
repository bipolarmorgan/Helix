use Mix.Config

config :helix_account,
  ecto_repos: [Helix.Account.Repo]

config :helix_account, Helix.Account.Repo,
  size: 4,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  database: "account_service"

config :guardian, Guardian,
  issuer: "account",
  ttl: {1, :days},
  allowed_algos: ["HS512"],
  secret_key: System.get_env("HELIX_JWK_KEY"),
  serializer: Helix.Account.Model.Session

import_config "#{Mix.env}.exs"