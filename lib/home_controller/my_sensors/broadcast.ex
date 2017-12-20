defmodule HomeController.MySensors.Broadcast do
  @moduledoc "Stage to Broadcast Repo Data."

  alias HomeController.MySensors
  use GenStage

  @doc false
  def start_link do
    GenStage.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc "Subscribe to events about MySensors Data."
  def subscribe(pid) do
    GenStage.call(__MODULE__, {:subscribe, pid})
  end

  defmodule State do
    @moduledoc false
    defstruct [subscribers: []]
    @typedoc false
    @type t :: %__MODULE__{subscribers: [pid]}
  end

  def init([]) do
    gen_stage_opts = [
      subscribe_to: [MySensors.Gateway],
      dispatcher: GenStage.BroadcastDispatcher
    ]
    {:producer_consumer, struct(State, []), gen_stage_opts}
  end

  def handle_events(events, state) do
    for pid <- state.subscribers do
      for event <- events do
        send pid, {:my_sensors, event}
      end
    end
    {:noreply, events, state}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, [], %{state | subscribers: [pid | state.subscribers]}}
  end

  def handle_info({:DOWN, _, :process, pid, _reason}, state) do
    new_subscribers = List.delete(state.subscribers, pid)
    {:noreply, [], %{state | subscribers: new_subscribers}}
  end
end
