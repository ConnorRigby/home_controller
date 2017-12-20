defmodule HomeController.MySensors.Gateway do
  @moduledoc "Handles parsed MySensors packets."
  use GenStage
  require Logger
  alias HomeController.MySensors.Packet
  alias HomeController.MySensors.{Node, Sensor, SensorValue, Context}

  use Packet.Constants

  defmodule State do
    @moduledoc false
    defstruct [:transport, :transport_pid, :status]
    @typedoc false
    @type t :: %__MODULE__{
      transport: module,
      transport_pid: pid,
      status: map
    }
  end

  @doc false
  def start_link do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc "Get Gateway status."
  def status do
    GenStage.call(__MODULE__, :status)
  end

  @doc "Send a packet."
  def write_packet(%Packet{} = packet) do
    GenStage.call(__MODULE__, {:write_packet, packet})
  end

  @doc false
  def init([]) do
    transport = Application.get_env(:home_controller, :my_sensors)[:transport]
    case transport do
      nil -> {:stop, :no_transport}
      mod when is_atom(mod) ->
        case mod.start_link() do
          {:ok, pid} ->
            state = struct(State, [transport: transport, transport_pid: pid, status: %{}])
            gen_stage_opts = [subscribe_to: [pid]]
            {:consumer, state, gen_stage_opts}
          {:error, reason} -> {:stop, {:transport_start_fail, reason}}
          err -> err
        end
    end
  end

  def handle_call(:status, _, state) do
    {:reply, state.status, [], state}
  end

  def handle_call({:write_packet, packet}, _, state) do
    res = state.transport.write(packet)
    {:reply, res, [], state}
  end

  @doc false
  def handle_events(packets, _, state) do
    do_handle_packets(packets, state)
  end

  @spec do_handle_packets([Packet.t], State.t) :: {:noreply, State.t}

  defp do_handle_packets(packets, state)

  defp do_handle_packets([%Packet{} = packet | rest], state) do
    case do_handle_packet(packet, state) do
      %State{} = new_state ->
        do_handle_packets(rest, new_state)
      err -> {:stop, err, state}
    end
  end

  defp do_handle_packets([], state) do
    {:noreply, [], state}
  end

  # Handles packet by command.
  @spec do_handle_packet(Packet.t, State.t) :: {[any], State.t}
  defp do_handle_packet(%Packet{command: @command_PRESENTATION, node_id: 0}, state) do
    state
  end

  defp do_handle_packet(%Packet{command: @command_PRESENTATION, child_sensor_id: @internal_NODE_SENSOR_ID} = packet, state) do
    with {:ok, %Node{}} <- Context.save_protocol(packet),
    {:ok, %Sensor{}} <- Context.save_sensor(packet) do
      state
    else
      err -> err
    end
  end

  defp do_handle_packet(%Packet{command: @command_PRESENTATION} = packet, state) do
    case Context.save_sensor(packet) do
      {:ok, %Sensor{}} -> state
      err -> err
    end
  end

  defp do_handle_packet(%Packet{command: @command_SET} = packet, state) do
    case Context.save_sensor_value(packet) do
      {:ok, %SensorValue{}} -> state
      err -> err
    end
  end

  defp do_handle_packet(%Packet{command: @command_REQ}, state), do: state

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_BATTERY_LEVEL} = packet, state) do
    case Context.save_battery_level(packet) do
      {:ok, %Node{}} -> state
      err -> err
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_TIME} = packet, state) do
    send_time(packet, state)
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_ID_REQUEST} = packet, state) do
    case send_next_available_id(packet, state) do
      {:ok, %Node{}} -> state
      err -> err
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_CONFIG} = packet, state) do
    case send_config(packet, state) do
      {:ok, %Node{}} -> state
      err -> err
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_SKETCH_NAME} = packet, state) do
    case Context.save_sketch_name(packet) do
      {:ok, %Node{}} -> state
      err -> err
    end
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_SKETCH_VERSION} = packet, state) do
    case Context.save_sketch_version(packet) do
      {:ok, %Node{}} -> state
      err -> err
    end
  end


  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_LOG_MESSAGE} = packet, state) do
    Logger.info "Node #{packet.node_id} => #{packet.payload}"
    state
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: @internal_GATEWAY_READY}, state) do
    %{state | status: Map.put(state.status, :ready, true)}
  end

  defp do_handle_packet(%Packet{command: @command_INTERNAL} = packet, state) do
    Logger.debug "Unhandled internal message: #{inspect packet}"
    state
  end

  defp do_handle_packet(%Packet{command: @command_STREAM}, state),
    do: state

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

  @spec send_config(Packet.t, State.t) :: {:ok, Node.t} | {:error, term}
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
      :ok -> Context.save_config(send_packet)
      err -> err
    end
  end

  @spec send_next_available_id(Packet.t, State.t) :: {:ok, Node.t} | {:error, term}
  defp send_next_available_id(%Packet{}, state) do
    node = Context.new_node()

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
        Context.delete_node(node.id)
        {:error, reason}
    end
  end
end
