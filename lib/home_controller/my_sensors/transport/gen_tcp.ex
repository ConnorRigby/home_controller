defmodule HomeController.MySensors.Transport.GenTCP do
  @moduledoc "gen_tcp Tranport for MySensors."
  @behaviour HomeController.MySensors.Transport
  use GenStage
  require Logger
  alias HomeController.MySensors.Packet

  @doc false
  def start_link do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def write(packet) do
    GenStage.call(__MODULE__, {:write, packet}, :infinity)
  end

  defmodule State do
    @moduledoc false
    defstruct [:socket]
  end

  @doc false
  def init([]) do
    host = Application.get_env(:home_controller, :my_sensors_transport)[:host]
    port = Application.get_env(:home_controller, :my_sensors_transport)[:port]
    case :gen_tcp.connect(host, port, [:binary, {:active, true}]) do
      {:ok, socket} ->
        state = struct(State, [socket: socket])
        {:producer, state}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc false
  def handle_demand(_, state), do: {:noreply, [], state}

  def handle_info({:tcp, _socket, command}, state) when is_binary(command) do
    with {:ok, decoded} <- Packet.decode(command) do
      Logger.debug "packet in: #{inspect decoded}"
      {:noreply, [decoded], state}
    else
      {:error, reason} ->
        Logger.error "Error decoding packet: #{command} #{inspect reason}"
        {:noreply, [], state}
    end
  end

  def handle_call({:write, packet}, _from, state) do
    with {:ok, decoded} <- Packet.encode(packet) do
      Logger.debug "packet out: #{inspect decoded}"
      r = :gen_tcp.send(state.socket, decoded)
      {:reply, r, [], state}
    else
      {:error, reason} ->
        Logger.error "Failed to encode packet: #{inspect packet} #{inspect reason}"
        {:reply, {:error, reason}, [], state}
    end
  end

  def terminate(_, state) do
    if state.socket do
      :gen_tcp.close(state.socket)
    end
  end
end
