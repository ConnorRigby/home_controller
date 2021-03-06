defmodule HomeController.MySensors.Context do
  @moduledoc "Repo Context for MySensors"
  alias HomeController.MySensors
  alias MySensors.{Broadcast, Packet, Repo, Node, Sensor, SensorValue}
  alias Ecto.Multi
  import Ecto.Query
  require Logger

  @doc "Get a node"
  @spec get_node(integer) :: Node.t | nil
  def get_node(id) do
    Repo.one(from n in Node,
      where: n.id == ^id,
      left_join: sensors in assoc(n, :sensors),
      left_join: sensor_values in assoc(sensors, :sensor_values),
      preload: [sensors: {sensors, sensor_values: sensor_values}]
    )
  end

  @doc "Delete a node by id."
  def delete_node(id) do
    node = get_node(id)
    Multi.new()
      |> Multi.delete(:delete, node)
      |> Multi.run(:broadcast, &Broadcast.notify/1)
      |> Repo.transaction
      |> case do
        {:ok, _} -> node
        _ -> {:error, :could_not_delete_node}
      end
  end

  def all_nodes() do
    Repo.all(Node) |> Repo.preload([sensors: :sensor_values])
  end

  def new_node do
    struct(Node, [])
      |> Node.changeset(%{})
      |> Repo.insert!()
      |> Repo.preload([sensors: :sensor_values])
  end

  defp insert_or_update_node(changeset) do
    Multi.new()
    |> Multi.insert_or_update(:insert_or_update, changeset)
    |> Multi.run(:broadcast, &Broadcast.notify/1)
    |> Repo.transaction()
    |> case do
      {:ok, %{broadcast: %Node{} = node}} -> {:ok, node}
      {:ok, %{broadcast: _}} -> {:error, :broadcast_fail}
      _ -> {:error, :node_insert_or_update_fail}
    end
  end

  def update_node(node, params) do
    changeset = Node.changeset(node, params)
    Multi.new()
    |> Multi.insert_or_update(:insert_or_update, changeset)
    |> Multi.run(:broadcast, &Broadcast.notify/1)
    |> Repo.transaction()
    |> case do
      {:ok, %{broadcast: %Node{} = node}} -> {:ok, node}
      {:ok, %{broadcast: _}} -> {:error, :broadcast_fail}
      _ -> {:error, :node_insert_or_update_fail}
    end
  end

  @doc "Saves the protocol of a node."
  @spec save_protocol(Packet.t) :: {:ok, Node.t} | {:error, term}
  def save_protocol(%Packet{} = packet) do
    node_opts = [id: packet.node_id, protocol: packet.payload]
    (get_node(packet.node_id) || struct(Node, node_opts))
    |> Node.changeset(%{protocol: packet.payload})
    |> insert_or_update_node()
  end

  def save_config(%Packet{node_id: node_id, payload: config}) do
    (get_node(node_id) || struct(Node, [id: node_id, config: config]))
    |> Node.changeset(%{config: config})
    |> insert_or_update_node()
  end

  @doc "Save a node's battery_level"
  @spec save_battery_level(Packet.t) :: {:ok, Node.t} | {:error, term}
  def save_battery_level(%Packet{} = packet) do
    opts = [id: packet.node_id, battery_level: packet.payload]
    (get_node(packet.node_id) || struct(Node, opts))
    |> Node.changeset(%{battery_level: packet.payload})
    |> insert_or_update_node()
  end

  @doc "Save a node's sketch_name"
  @spec save_sketch_name(Packet.t) :: {:ok, Node.t} | {:error, term}
  def save_sketch_name(%Packet{} = packet) do
    opts = [id: packet.node_id, sketch_name: packet.payload]
    (get_node(packet.node_id) || struct(Node, opts))
    |> Node.changeset(%{sketch_name: packet.payload})
    |> insert_or_update_node()
  end

  @doc "Save a node's sketch_version"
  @spec save_sketch_version(Packet.t) :: {:ok, Node.t} | {:error, term}
  def save_sketch_version(%Packet{} = packet) do
    opts = [id: packet.node_id, sketch_version: packet.payload]
    (get_node(packet.node_id) || struct(Node, opts))
    |> Node.changeset(%{sketch_version: packet.payload})
    |> insert_or_update_node()
  end

  @doc "Save a sensor on a node."
  @spec save_sensor(Packet.t) :: {:ok, Sensor.t} | {:error, term}
  def save_sensor(%Packet{node_id: node_id, child_sensor_id: sid} = packet) do
    sensor_opts = [
      node_id: node_id,
      child_sensor_id: sid,
      type: to_string(packet.type)
    ]
    sensor = (get_sensor(node_id, sid) || struct(Sensor, sensor_opts))
    changeset = sensor
      |> Sensor.changeset(Map.new(sensor_opts))
      |> Ecto.Changeset.put_assoc(:sensor_values, sensor.sensor_values)

    Multi.new()
      |> Multi.insert_or_update(:insert_or_update, changeset)
      |> Multi.run(:broadcast, &Broadcast.notify/1)
      |> Repo.transaction()
      |> case do
        {:ok, %{broadcast: %Sensor{} = node}} -> {:ok, node}
        {:ok, %{broadcast: _}} -> {:error, :broadcast_fail}
        _ -> {:error, :node_insert_or_update_fail}
      end
  end

  @doc "Save a sensor_value from a sensor."
  @spec save_sensor_value(Packet.t) :: {:ok, SensorValue.t} | {:error, term}
  def save_sensor_value(%Packet{} = packet) do
    {value, _} = Float.parse(packet.payload)
    sensor = get_sensor(packet.node_id, packet.child_sensor_id)
    if sensor do
      opts = [sensor_id: sensor.id, type: to_string(packet.type), value: value]
      sv = struct(SensorValue, opts)
      changeset = SensorValue.changeset(sv, %{})
      Multi.new()
      |> Multi.insert(:insert_or_update, changeset)
      |> Multi.run(:broadcast, &Broadcast.notify/1)
      |> Repo.transaction
      |> case do
        {:ok, %{broadcast: %SensorValue{} = sv}} -> {:ok, sv}
        {:ok, %{broadcast: _}} -> {:error, :broadcast_fail}
        _ -> {:error, :node_insert_or_update_fail}
      end
    else
      Logger.warn "Got sensor value for unknown sensor."
      {:error, :no_sensor}
    end
  end

  @doc "Get a sensor from node_id and sensor_id"
  @spec get_sensor(integer, integer) :: Sensor.t | nil
  def get_sensor(node_id, child_sensor_id) do
    query = from s in Sensor,
      where: s.node_id == ^node_id and s.child_sensor_id == ^child_sensor_id,
      preload: [:node, :sensor_values]
    Repo.one(query)
  end

  def all_sensors(node_id) do
    query = from s in Sensor,
      where: s.node_id == ^node_id,
      preload: [:node, :sensor_values]
    Repo.all(query)
  end
end
