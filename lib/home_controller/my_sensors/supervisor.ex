defmodule HomeController.MySensors.Supervisor do
  @moduledoc false
  alias HomeController.MySensors

  use Supervisor

  @doc false
  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    children = [
      worker(MySensors.Gateway, [])
    ]
    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end
