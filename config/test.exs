use Mix.Config

config :home_controller, :my_sensors, [
  transport: HomeController.MySensors.Transport.Local
]
