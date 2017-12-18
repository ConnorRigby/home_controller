defmodule HomeController.MySensors.SensorValue do
  @moduledoc "SensorValue Object"

  use Ecto.Schema
  import Ecto.Changeset
  alias HomeController.MySensors
  alias MySensors.{Sensor, SensorValue}

  schema "sensor_values" do
    belongs_to :sensor, Sensor
    field :type, :string
    field :value, :float
    timestamps()
  end

  @optional_params []
  @required_params [:sensor_id, :type, :value]

  def changeset(%SensorValue{} = sensor_value, params \\ %{}) do
    sensor_value
    |> cast(params, @optional_params ++ @required_params)
    |> validate_required(@required_params)
  end
end
