defmodule HomeController.MySensors.Transport.UART do
  @moduledoc "UART Tranport for MySensors."
  @behaviour HomeController.MySensors.Transport
  alias Nerves.UART
  use GenStage
  require Logger

  @device Application.get_env(:home_controller, :my_sensors_transport)[:device]
  @speed Application.get_env(:home_controller, :my_sensors_transport)[:speed]
  @seperator Application.get_env(:home_controller, :my_sensors_transport)[:seperator]

  def write(packet), do: GenStage.call(__MODULE__, {:write, packet}, :infinity)

  def start_link do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    {:ok, uart} = UART.start_link()
    case UART.open(uart, @device, active: true, speed: @speed) do
      :ok ->
        :ok = UART.configure(uart, framing: {UART.Framing.Line, separator: @seperator})
        {:producer, %{uart: uart}}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_demand(_, state), do: {:noreply, [], state}

  def handle_info({:nerves_uart, _, {:error, error}}, state) do
    {:stop, error, state}
  end

  def handle_info({:nerves_uart, _, {:partial, _}}, state) do
    {:noreply, [], state}
  end

  def handle_info({:nerves_uart, _, command}, state) do
    with {:ok, decoded} <- HomeController.MySensors.Packet.decode(command) do
      {:noreply, [decoded], state}
    else
      {:error, reason} ->
        Logger.error "Error decoding packet: #{command} #{inspect reason}"
        {:noreply, [], state}
    end
  end

  def handle_call({:write, packet}, _from, state) do
    with {:ok, packet} <- HomeController.MySensors.Packet.encode(packet) do
      r = UART.write(state.uart, packet)
      {:reply, r, [], state}
    else
      {:error, reason} ->
        Logger.error "Failed to encode packet: #{inspect packet} #{inspect reason}"
        {:reply, {:error, reason}, [], state}
    end
  end
end
