use Mix.Config

config :home_controller, system_init: [
  before_system: [HomeController.Target.Network],
  after_init: []
]
