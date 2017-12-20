defmodule HomeController.System.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    before_system = Application.get_env(:home_controller, :system_init)[:before_system]
    after_system = Application.get_env(:home_controller, :system_init)[:after_init]
    children =
      before_system ++ [

      ] ++ after_system
      |> Enum.map(fn(init_sup) ->
        supervisor(init_sup, [])
      end)
    opts = [strategy: :one_for_all]
    supervise(children, opts)
  end
end
