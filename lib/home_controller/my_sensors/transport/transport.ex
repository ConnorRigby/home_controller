defmodule HomeController.MySensors.Transport do
  @moduledoc """
  Behaviour for MySensors transports to implement.

  Should have configuration in `config.exs`

      config :home_controller, :my_sensors, [
        transport: HomeController.MySensors.Transport.Local
      ]

  each `transport` may also have a config bag:
      config :home_controller, :my_sensors_transport, [
        some_key: "some_configuration_value",
        any_ole_data: %{sub_key: 123}
      ]
  """
  alias HomeController.MySensors.Packet

  @doc "Write a packet."
  @callback write(Packet.t) :: :ok | {:error, term}

  @doc "Should be a GenStage `start_link`"
  @callback start_link :: GenServer.on_start()
end
