defmodule HomeController.MySensors.Transport do
  @moduledoc "Behaviour for MySensors transports to implement."
  alias HomeController.MySensors.Packet

  @doc "Write a packet."
  @callback write(Packet.t) :: :ok | {:error, term}

  @doc false
  @callback start_link :: GenServer.on_start()
end
