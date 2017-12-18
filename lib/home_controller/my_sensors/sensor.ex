defmodule HomeController.MySensors.Sensor do
  @moduledoc "Sensor Object"

  use Ecto.Schema
  import Ecto.Changeset
  alias HomeController.MySensors
  alias MySensors.{Node, Sensor, SensorValue}

  schema "sensors" do
    belongs_to :node, Node
    has_many :sensor_values, SensorValue
    field :child_sensor_id, :integer
    field :type, :string
    timestamps()
  end

  @optional_params []
  @required_params [:node_id, :child_sensor_id, :type]

  def changeset(%Sensor{} = sensor, params \\ %{}) do
    sensor
    |> cast(params, @optional_params ++ @required_params)
    |> validate_required(@required_params)
  end
end
