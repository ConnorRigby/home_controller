defmodule HomeController.Target.Network do
  @moduledoc "Network"

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    wait_for_interface("eth0")
    children = [
      worker(Task, [__MODULE__, :start_interface, ["eth0"]], [restart: :transient])
    ]
    opts = [strategy: :one_for_one]
    supervise(children, opts)
  end

  defp wait_for_interface(iface) do
    unless iface in Nerves.Network.Interface.interfaces() do
      wait_for_interface(iface)
    end
  end

  defp start_interface(iface, opts \\ []) do
    Nerves.Network.setup(iface, opts)
  end
end
