defmodule HomeController.MySensors.Web.LanApp.SocketHandler do
  @moduledoc "Lan App WebSocket Server."

  @timeout 60_000
  def websocket_init(_type, req, _options) do
    state = %{}
    {:ok, req, state, @timeout}
  end

  # messages from the browser.
  def websocket_handle({:text, m}, req, state) do
    {:ok, req, state}
  end

  def websocket_info(info, req, state) do
    {:ok, req, state}
  end
end
