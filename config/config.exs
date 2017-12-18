# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Customize the firmware. Uncomment all or parts of the following
# to add files to the root filesystem or modify the firmware
# archive.

# config :nerves, :firmware,
#   rootfs_overlay: "rootfs_overlay",
#   fwup_conf: "config/fwup.conf"

# Use bootloader to start the main application. See the bootloader
# docs for separating out critical OTP applications such as those
# involved with firmware updates.
config :bootloader,
  init: [:nerves_runtime],
  app: Mix.Project.config[:app]

config :home_controller, :my_sensors, [
  transport: HomeController.MySensors.Transport.UART
  # transport: HomeController.MySensors.Transport.Test
]

config :home_controller, :my_sensors_transport, [
  speed: 115200,
  seperator: "\n",
  device: "/dev/ttyUSB0"
]

config :home_controller, HomeController.MySensors.Repo,
  adapter: Sqlite.Ecto2,
  database: "my_sensors.sqlite3",
  priv: "priv/my_sensors/repo"

config :home_controller, ecto_repos: [HomeController.MySensors.Repo]

import_config "#{Mix.env()}.exs"

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.Project.config[:target]}.exs"
