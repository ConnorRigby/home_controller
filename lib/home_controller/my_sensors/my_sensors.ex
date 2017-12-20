defmodule HomeController.MySensors do
  @moduledoc """
  The `MySensors` part of the app has a few parts:
  * [Packet](HomeController.MySensors.Packet) - An Elixir Parsed packet.
  * [Gateway](HomeController.MySensors.Gateway.html) - Handles parsed Packets.
    * [Gateway.Transport](HomeController.MySensors.Gateway.Transport.html) -
    A GenStage behaviour for `Transport`s to implement.
      * [UART Transport](HomeController.MySensors.Transport.UART.html) ->
      A transport to a `serial_gateway` sketch.
      * [TCP Transport](HomeController.MySensors.Transport.GenTCP.html) ->
      A transport to a `ethernet_gateway` sketch.
  * [Repo](HomeController.MySensors.Repo.html) - Database to store
  [Node](HomeController.MySensors.Node.html),
  [Sensor](HomeController.MySensors.Sensor.html),
  and [SensorValue](HomeController.MySensors.SensorValue.html) data.
  """
end
