defmodule HomeController.MySensors.Context do
  @moduledoc "Repo Context for MySensors"
  alias HomeController.MySensors
  alias MySensors.{Repo, Node, Sensor}
  import Ecto.Query

  @doc "Get a node"
  @spec get_node(integer) :: Node.t | nil
  def get_node(id) do
    Repo.one(from n in Node, where: n.id == ^id)
  end

  @doc "Get a sensor from node_id and sensor_id"
  @spec get_sensor(integer, integer) :: Sensor.t | nil
  def get_sensor(node_id, child_sensor_id) do
    query = from s in Sensor,
      where: s.node_id == ^node_id and s.child_sensor_id == ^child_sensor_id
    Repo.one(query)
  end
end
