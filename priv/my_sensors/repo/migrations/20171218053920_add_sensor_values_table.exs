defmodule HomeController.MySensors.Repo.Migrations.AddSensorValuesTable do
  use Ecto.Migration

  def change do
    create table("sensor_values") do
      add :sensor_id, references("sensors")
      add :value, :float
      add :type, :string
      timestamps()
    end
  end
end
