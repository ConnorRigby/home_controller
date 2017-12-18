defmodule HomeController.MySensors.Gateway do
  @moduledoc "Handles parsed MySensors packets."
  use GenStage
  require Logger
  alias HomeController.MySensors.Packet
  use Packet.Constants

  defmodule State do
    @moduledoc false
    defstruct [:transport, :transport_pid]
  end

  def start_link do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    transport = Application.get_env(:home_controller, :my_sensors)[:transport]
    case transport do
      nil -> {:stop, :no_transport}
      mod when is_atom(mod) ->
        case mod.start_link() do
          {:ok, pid} ->
            state = struct(State, [transport: transport, transport_pid: pid])
            {:consumer, state, [subscribe_to: [pid]]}
          err -> err
        end
    end
  end

  def handle_events(packets, _, state) do
    do_handle_packets(packets, state)
  end

  defp do_handle_packets([%Packet{} = packet | rest], state) do
    new_state = do_handle_packet(packet, state)
    do_handle_packets(rest, new_state)
  end

  defp do_handle_packets([], state), do: {:noreply, [], state}

  # Handles packet by command.
  defp do_handle_packet(%Packet{command: @command_PRESENTATION, node_id: 0}, state) do
    state
  end

  defp do_handle_packet(%Packet{command: @command_PRESENTATION} = packet, state) do
    if packet.node_id == @internal_NODE_SENSOR_ID do
      save_protocol(packet)
    end
    save_sensor(packet)
    state
  end

  defp do_handle_packet(%Packet{command: @command_SET} = packet, state) do
    save_sensor_value(packet)
    state
  end

  defp do_handle_packet(%Packet{command: @command_REQ}, state), do: state

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_BATTERY_LEVEL} = packet, state) do
    save_battery_level(packet)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_TIME} = packet, state) do
    send_time(packet, state)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_ID_REQUEST} = packet, state) do
    send_next_available_id(packet, state)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_CONFIG} = packet, state) do
    send_config(packet, state)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_SKETCH_NAME} = packet, state) do
    save_sketch_name(packet)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_SKETCH_VERSION} = packet, state) do
    save_sketch_version(packet)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: _}, state), do: state

  defp do_handle_packet(%Packet{command: @command_STREAM}, state), do: state

  alias HomeController.MySensors.{Repo, Node, Sensor, SensorValue, Context}

  def save_protocol(%Packet{} = packet) do
    (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, protocol: packet.payload]))
    |> Node.changeset(%{protocol: packet.payload})
    |> Repo.insert_or_update()
  end

  def save_sensor(%Packet{} = packet) do
    (Context.get_sensor(packet.node_id, packet.child_sensor_id) || struct(Sensor, [node_id: packet.node_id, child_sensor_id: packet.child_sensor_id, type: to_string(packet.type)]))
    |> Sensor.changeset(%{node_id: packet.node_id, child_sensor_id: packet.child_sensor_id, type: to_string(packet.type)})
    |> Repo.insert_or_update()
  end

  def save_sensor_value(%Packet{} = packet) do
    {value, _} = Float.parse(packet.payload)
    sensor = Context.get_sensor(packet.node_id, packet.child_sensor_id)
    if sensor do
      sv = struct(SensorValue, [sensor_id: sensor.id, type: to_string(packet.type), value: value])
      SensorValue.changeset(sv, %{})
      |> Repo.insert()
    else
      Logger.warn "Got sensor value for unknown sensor."
    end
  end

  def save_battery_level(%Packet{} = packet) do
    (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, battery_level: packet.payload]))
    |> Node.changeset(%{battery_level: packet.payload})
    |> Repo.insert_or_update()
  end

  def save_sketch_name(%Packet{} = packet) do
    (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, sketch_name: packet.payload]))
    |> Node.changeset(%{sketch_name: packet.payload})
    |> Repo.insert_or_update()
  end

  def save_sketch_version(%Packet{} = packet) do
    (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, sketch_version: packet.payload]))
    |> Node.changeset(%{sketch_version: packet.payload})
    |> Repo.insert_or_update()
  end

  def send_time(%Packet{} = packet, state) do
    time = :os.system_time(:seconds)
    opts = [command: @command_INTERNAL,
            ack: @ack_FALSE,
            node_id: packet.node_id,
            child_sensor_id: packet.child_sensor_id,
            type: @internal_TIME,
            payload: to_string(time)
          ]
    send_packet = struct(Packet, opts)
    state.transport.write(send_packet)
  end

  def send_config(%Packet{} = packet, state) do
    opts = [
      payload: "M",
      child_sensor_id: @internal_NODE_SENSOR_ID,
      node_id: packet.node_id,
      command: @command_INTERNAL,
      type: @internal_CONFIG,
      ack: @ack_FALSE
    ]
    send_packet = struct(Packet, opts)
    state.transport.write(send_packet)
  end

  def send_next_available_id(%Packet{}, state) do
    {:ok, node} = struct(Node, [])
      |> Node.changeset(%{})
      |> Repo.insert_or_update()

    packet_opts = [
      node_id: @internal_BROADCAST_ADDRESS,
      child_sensor_id: @internal_NODE_SENSOR_ID,
      command: @command_INTERNAL,
      type: @internal_ID_RESPONSE,
      ack: @ack_FALSE,
      payload: node.id
    ]
    send_packet = struct(Packet, packet_opts)
    state.transport.write(send_packet)
  end
end
