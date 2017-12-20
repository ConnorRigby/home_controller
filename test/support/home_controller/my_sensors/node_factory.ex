defmodule HomeController.MySensors.NodeFactory do
  @moduledoc """
  Generate Nodes whenever you want.
  """

  alias HomeController.MySensors.Transport.Test
  import Test, only: [dispatch: 1]
  alias HomeController.MySensors.Packet
  use HomeController.MySensors.Packet.Constants

  def generate_node(sketch_name) do
    Test.register(self())
    id_request = %Packet{
      node_id: @internal_NODE_SENSOR_ID,
      command: @command_INTERNAL,
      type: @internal_ID_REQUEST
    }
    id_response = dispatch_and_fetch(id_request)
    node_id = id_response.payload

    %Packet{
      command: @command_INTERNAL,
      type: @internal_SKETCH_NAME,
      node_id: node_id,
      payload: sketch_name
    } |> dispatch()

    %Packet{
      command: @command_INTERNAL,
      type: @internal_SKETCH_VERSION,
      node_id: node_id,
      payload: "v0.1.2"
    } |> dispatch()

    %Packet{
      command: @command_PRESENTATION,
      node_id: node_id,
      child_sensor_id: @internal_NODE_SENSOR_ID,
      type: @sensor_ARDUINO_REPEATER_NODE,
      payload: "sensor_factory"
    } |> dispatch()
  end

  def dispatch_and_fetch(packet) do
    dispatch(packet)
    get_packet()
  end

  def get_packet do
    receive do
      %Packet{} = packet -> packet
    after 1000 -> exit(:timeout)
    end
  end
end
