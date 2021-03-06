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
      supervisor(MySensors.Repo, []),
      worker(MySensors.Gateway, []),
      worker(MySensors.Broadcast, []),
      supervisor(MySensors.Web.LanApp.Supervisor, [])
    ]
    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end
