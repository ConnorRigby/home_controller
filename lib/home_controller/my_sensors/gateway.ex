defmodule HomeController.MySensors.Gateway do
  @moduledoc "Handles parsed MySensors packets."
  use GenStage
  require Logger
  alias HomeController.MySensors.Packet
  alias HomeController.MySensors.{Repo, Node, Sensor, SensorValue, Context}

  use Packet.Constants

  defmodule State do
    @moduledoc false
    defstruct [:transport, :transport_pid]
    @typedoc false
    @type t :: %__MODULE__{
      transport: module,
      transport_pid: pid
    }
  end

  @doc false
  def start_link do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc false
  def init([]) do
    transport = Application.get_env(:home_controller, :my_sensors)[:transport]
    case transport do
      nil -> {:stop, :no_transport}
      mod when is_atom(mod) ->
        case mod.start_link() do
          {:ok, pid} ->
            state = struct(State, [transport: transport, transport_pid: pid])
            gen_stage_opts = [
              subscribe_to: [pid]
            ]
            {:producer_consumer, state, gen_stage_opts}
          {:error, reason} -> {:stop, {:transport_start_fail, reason}}
          err -> err
        end
    end
  end

  @doc false
  def handle_events(packets, _, state) do
    do_handle_packets(packets, [], state)
  end

  @spec do_handle_packets([Packet.t], [any], State.t) :: {:noreply, [any], State.t}
  defp do_handle_packets(packets, acc, state)

  defp do_handle_packets([%Packet{} = packet | rest], acc, state) do
    {dispatch, new_state} = do_handle_packet(packet, state)
    do_handle_packets(rest, acc ++ dispatch, new_state)
  end

  defp do_handle_packets([], acc, state), do: {:noreply, acc, state}

  # Handles packet by command.
  @spec do_handle_packet(Packet.t, State.t) :: {[any], State.t}
  defp do_handle_packet(%Packet{command: @command_PRESENTATION, node_id: 0}, state) do
    {[], state}
  end

  defp do_handle_packet(%Packet{command: @command_PRESENTATION, child_sensor_id: @internal_NODE_SENSOR_ID} = packet, state) do
    with {:ok, %Node{} = node} <- save_protocol(packet),
    {:ok, %Sensor{} = sensor} <- save_sensor(packet) do
      {[{:insert_or_update, node}, {:insert_or_update, sensor}], state}
    else
      _ -> {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_PRESENTATION} = packet, state) do
    case save_sensor(packet) do
      {:ok, %Sensor{} = sensor} ->
        {[{:insert_or_update, sensor}], state}
      _ -> {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_SET} = packet, state) do
    case save_sensor_value(packet) do
      {:ok, %SensorValue{} = sv} ->
        {[{:insert_or_update, sv}], state}
      _ -> {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_REQ}, state), do: {[], state}

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_BATTERY_LEVEL} = packet, state) do
    case save_battery_level(packet) do
      {:ok, %Node{} = node} ->
        {[{:insert_or_update, node}], state}
      _ -> {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_TIME} = packet, state) do
    send_time(packet, state)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_ID_REQUEST} = packet, state) do
    case send_next_available_id(packet, state) do
      {:ok, %Node{} = node} ->
        {[{:insert_or_update, node}], state}
      _ -> {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_CONFIG} = packet, state) do
    case send_config(packet, state) do
      {:ok, %Node{} = node} ->
        {[{:insert_or_update, node}], state}
      _ ->
        {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_SKETCH_NAME} = packet, state) do
    case save_sketch_name(packet) do
      {:ok, %Node{} = node} ->
        {[{:insert_or_update, node}], state}
      _ ->
        {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_SKETCH_VERSION} = packet, state) do
    case save_sketch_version(packet) do
      {:ok, %Node{} = node} ->
        {[{:insert_or_update, node}], state}
      _ ->
        {[], state}
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: _}, state),
    do: {[], state}

  defp do_handle_packet(%Packet{command: @command_STREAM}, state),
    do: {[], state}

  @doc "Saves the protocol of a node."
  @spec save_protocol(Packet.t) :: {:ok, Node.t} | {:error, Ecto.Changeset.t}
  def save_protocol(%Packet{} = packet) do
    node_opts = [id: packet.node_id, protocol: packet.payload]
    (Context.get_node(packet.node_id) || struct(Node, node_opts))
    |> Node.changeset(%{protocol: packet.payload})
    |> Repo.insert_or_update()
  end

  @doc "Save a sensor on a node."
  @spec save_sensor(Packet.t) :: {:ok, Sensor.t} | {:error, Ecto.Changeset.t}
  def save_sensor(%Packet{node_id: node_id, child_sensor_id: sid} = packet) do
    sensor_opts = [
      node_id: node_id,
      child_sensor_id: sid,
      type: to_string(packet.type)
    ]
    (Context.get_sensor(node_id, sid) || struct(Sensor, sensor_opts))
    |> Sensor.changeset(Map.new(sensor_opts))
    |> Repo.insert_or_update()
  end

  @doc "Save a sensor_value from a sensor."
  @spec save_sensor_value(Packet.t) :: {:ok, SensorValue.t} |
    {:error, :no_sensor} |
    {:error, Ecto.Changeset.t}
  def save_sensor_value(%Packet{} = packet) do
    {value, _} = Float.parse(packet.payload)
    sensor = Context.get_sensor(packet.node_id, packet.child_sensor_id)
    if sensor do
      sv = struct(SensorValue, [sensor_id: sensor.id, type: to_string(packet.type), value: value])
      SensorValue.changeset(sv, %{})
      |> Repo.insert()
    else
      Logger.warn "Got sensor value for unknown sensor."
      {:error, :no_sensor}
    end
  end

  @doc "Save a node's battery_level"
  @spec save_battery_level(Packet.t) :: {:ok, Node.t} | {:error, Ecto.Changeset.t}
  def save_battery_level(%Packet{} = packet) do
    (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, battery_level: packet.payload]))
    |> Node.changeset(%{battery_level: packet.payload})
    |> Repo.insert_or_update()
  end

  @doc "Save a node's sketch_name"
  @spec save_sketch_name(Packet.t) :: {:ok, Node.t} | {:error, Ecto.Changeset.t}
  def save_sketch_name(%Packet{} = packet) do
    (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, sketch_name: packet.payload]))
    |> Node.changeset(%{sketch_name: packet.payload})
    |> Repo.insert_or_update()
  end

  @doc "Save a node's sketch_version"
  @spec save_sketch_version(Packet.t) :: {:ok, Node.t} | {:error, Ecto.Changeset.t}
  def save_sketch_version(%Packet{} = packet) do
    (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, sketch_version: packet.payload]))
    |> Node.changeset(%{sketch_version: packet.payload})
    |> Repo.insert_or_update()
  end

  @spec send_time(Packet.t, State.t) :: :ok | {:error, term}
  defp send_time(%Packet{} = packet, state) do
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

  @spec send_config(Packet.t, State.t) :: {:ok, Node.t} |
  {:error, Ecto.Changeset.t} |
  {:error, term}
  defp send_config(%Packet{} = packet, state) do
    opts = [
      payload: "M",
      child_sensor_id: @internal_NODE_SENSOR_ID,
      node_id: packet.node_id,
      command: @command_INTERNAL,
      type: @internal_CONFIG,
      ack: @ack_FALSE
    ]
    send_packet = struct(Packet, opts)
    case state.transport.write(send_packet) do
      :ok ->
        (Context.get_node(packet.node_id) || struct(Node, [id: packet.node_id, config: send_packet.payload]))
        |> Node.changeset(%{config: send_packet.payload})
        |> Repo.insert_or_update()
      err -> err
    end
  end

  @spec send_next_available_id(Packet.t, State.t) :: {:ok, Node.t} | {:error, term}
  defp send_next_available_id(%Packet{}, state) do
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
    case state.transport.write(send_packet) do
      :ok -> {:ok, node}
      {:error, reason} ->
        Logger.error "Failed to send next available id."
        Repo.delete(node)
        {:error, reason}
    end
  end
end
