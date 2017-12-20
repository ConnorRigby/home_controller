use Mix.Config

config :home_controller, :my_sensors, [
  transport: HomeController.MySensors.Transport.Local
]

config :home_controller, HomeController.MySensors.Repo,
  adapter: Sqlite.Ecto2,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "my_sensors_test.sqlite3",
  priv: "priv/my_sensors/repo"
