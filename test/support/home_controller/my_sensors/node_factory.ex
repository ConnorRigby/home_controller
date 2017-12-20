defmodule HomeController.MySensors.NodeFactory do
  @moduledoc """
  Generate Nodes whenever you want.
  """

  alias HomeController.MySensors.Transport.Test
  import Test, only: [dispatch: 1]
  alias HomeController.MySensors.Packet
  use HomeController.MySensors.Packet.Constants
  alias HomeController.MySensors.Context

  @app_version Mix.Project.config[:version]

  def generate_node(node  \\ nil, opts \\ []) do
    Test.register(self())

    # Broadcast new node, or use provided one.
    node = if node do
      node
    else
      id_request = %Packet{
        node_id: @internal_NODE_SENSOR_ID,
        command: @command_INTERNAL,
        type: @internal_ID_REQUEST
      }
      id_response = dispatch_and_fetch(id_request)
      Context.get_node(id_response.payload)
    end
    node_id = node.id

    # Broadcast sketch name.
    %Packet{
      command: @command_INTERNAL,
      child_sensor_id: @internal_NODE_SENSOR_ID,
      type: @internal_SKETCH_NAME,
      node_id: node_id,
      payload: Keyword.get(opts, :sketch_name, Faker.Pokemon.name)
    } |> dispatch()

    # Broadcast sketch version.
    %Packet{
      command: @command_INTERNAL,
      type: @internal_SKETCH_VERSION,
      child_sensor_id: @internal_NODE_SENSOR_ID,
      node_id: node_id,
      payload: Keyword.get(opts, :node_version, @app_version)
    } |> dispatch()

    # Broadcast node protocol.
    %Packet{
      command: @command_PRESENTATION,
      node_id: node_id,
      child_sensor_id: @internal_NODE_SENSOR_ID,
      type: @sensor_ARDUINO_REPEATER_NODE,
      payload: Keyword.get(opts, :node_protocol, to_string(__MODULE__))
    } |> dispatch()

    node
  end

  def generate_sensor(node, sensor_id, type, values) do
    %Packet{
      command: @command_PRESENTATION,
      child_sensor_id: sensor_id,
      type: type,
      node_id: node.id,
      payload: ""
    } |> dispatch()

    for value <- values do
      %Packet{
        command: @command_SET,
        child_sensor_id: sensor_id,
        type: type,
        node_id: node.id,
        payload: to_string(value)
      } |> dispatch()
    end
  end

  def dispatch_and_fetch(packet) do
    dispatch(packet)
    get_packet()
  end

  def get_packet do
    receive do
      %Packet{} = packet -> packet
    after 1000 ->
      exit(:timeout)
    end
  end
end
