defmodule HomeController.MySensors.Context do
  alias HomeController.MySensors
  alias MySensors.{Repo, Node, Sensor}
  import Ecto.Query

  @doc "Get a node"
  def get_node(id) do
    Repo.one(from n in Node, where: n.id == ^id)
  end

  def get_sensor(node_id, child_sensor_id) do
    Repo.one(from s in Sensor, where: s.node_id == ^node_id and s.child_sensor_id == ^child_sensor_id)
  end
end
