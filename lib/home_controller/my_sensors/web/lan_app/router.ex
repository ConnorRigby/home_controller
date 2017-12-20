defmodule HomeController.MySensors.Web.LanApp.Router do
  @moduledoc "Routes web connections for the Lan App."

  use Plug.Router
  use Plug.Debugger, otp_app: :home_controller
  plug(Plug.Static, from: {:home_controller, "priv/my_sensors/lan_app/static"}, at: "/")
  plug(Plug.Logger, log: :debug)
  plug(Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["application/json"], json_decoder: Poison)
  plug(:match)
  plug(:dispatch)

  alias HomeController.MySensors
  alias MySensors.Context
  import HomeController.MySensors.Web.LanApp.View

  ## CRUD API
  get "/api/v1/nodes" do
    nodes = Context.all_nodes()
    json = Poison.encode!(%{data: nodes})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  get "/api/v1/nodes/:id" do
    node = Context.get_node(id)
    json = Poison.encode!(%{data: node})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  delete "/api/v1/nodes/:id" do
    node = Context.delete_node(id)
    json = Poison.encode!(%{data: node})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  get "/api/v1/nodes/:node_id/sensors" do
    sensors = Context.all_sensors(node_id)
    json = Poison.encode!(%{data: sensors})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  get "/api/v1/nodes/:node_id/sensors/:sensor_id" do
    sensor = Context.get_sensor(node_id, sensor_id)
    json = Poison.encode!(%{data: sensor})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  get "/api/v1/gateway/status" do
    status = MySensors.Gateway.status()
    json = Poison.encode!(%{data: status})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  get "/api/v1/gateway/raw_packet/" do
    packet = conn.params["packet"]
    handle_raw_packet(conn, packet)
  end

  post "/api/v1/gateway/raw_packet" do
    packet = conn.body_params["packet"]
    handle_raw_packet(conn, packet)
  end

  defp handle_raw_packet(conn, nil) do
    json = Poison.encode!(%{data: %{ok: false, error: "packet can't be nil"}})
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, json)
  end

  defp handle_raw_packet(conn, packet) do
    with {:ok, %MySensors.Packet{} = packet} <- MySensors.Packet.decode(packet),
      :ok <- MySensors.Gateway.write_packet(packet) do
        json = Poison.encode!(%{data: %{ok: true}})
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, json)
      else
        error ->
          json = Poison.encode!(%{data: %{ok: false, error: "#{inspect error}"}})
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, json)
      end
  end

  get "/" do
    render_page(conn, "index")
  end

  get "/status" do
    gateway_status = MySensors.Gateway.status()
    render_page(conn, "status", [gateway_status: gateway_status])
  end

  get "/nodes" do
    nodes = Context.all_nodes() |> Enum.map(&render("node", [node: &1]))
    render_page(conn, "nodes", [nodes: nodes])
  end

  defp redir(conn, loc) do
    conn
    |> put_resp_header("location", loc)
    |> send_resp(302, loc)
  end

  defp render_page(conn, page, info \\ []) do
    content = render(page, info)
    html = render("layout", [content: content, page: page])
    send_resp(conn, 200, html)
  rescue
    e -> send_resp(conn, 500, "Failed to render page: #{page} inspect: #{Exception.message(e)}")
  end

  match(_, do: send_resp(conn, 404, "Page not found"))
end
