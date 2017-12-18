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
  defp do_handle_packet(%Packet{command: @command_PRESENTATION} = packet, state) do
    state
  end

  defp do_handle_packet(%Packet{command: @command_SET} = packet, state) do
    state
  end

  defp do_handle_packet(%Packet{command: @command_REQ} = packet, state), do: state

  defp do_handle_packet(%Packet{command: @command_INTERNAL, type: type}, state), do: state

  defp do_handle_packet(%Packet{command: @command_STREAM}, state), do: state
end
