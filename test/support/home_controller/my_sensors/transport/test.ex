defmodule HomeController.MySensors.Transport.Test do
  @moduledoc "Test implementation of a MySensors transport."
  @behaviour HomeController.MySensors.Transport
  alias HomeController.MySensors.Packet

  use GenStage

  @doc "Dispatch a packet to the Gateway. This is a test/debugging function."
  def dispatch(%Packet{} = packet) do
    GenStage.call(__MODULE__, {:dispatch, packet})
  end

  def dispatch([%Packet{} | _rest] = packets) do
    GenStage.call(__MODULE__, {:dispatch, packets})
  end

  def write(%Packet{} = _packet) do
    :ok
  end

  @doc false
  def start_link do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc false
  def init([]) do
    {:producer, []}
  end

  @doc false
  def handle_demand(_, state), do: {:noreply,  [], state}

  def handle_call({:dispatch, packets}, _, state) when is_list(packets) do
    {:reply, :ok, packets, state}
  end

  def handle_call({:dispatch, packet}, _, state) do
    {:reply, :ok, [packet], state}
  end
end
