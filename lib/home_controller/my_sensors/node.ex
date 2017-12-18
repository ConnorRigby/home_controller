defmodule HomeController.MySensors.Node do
  @moduledoc "Node Object"

  use Ecto.Schema
  import Ecto.Changeset
  alias HomeController.MySensors
  alias MySensors.Node

  schema "nodes" do
    has_many :sensors, MySensors.Sensor
    field :battery_level, :integer
    field :protocol, :string
    field :sketch_name, :string
    field :sketch_version, :string
    field :config, :string
    timestamps()
  end

  @typedoc @moduledoc
  @type t :: %__MODULE__{}

  @optional_params [:battery_level, :protocol, :sketch_name, :sketch_version, :config]
  @required_params []

  def changeset(%Node{} = node, params \\ %{}) do
    node
      |> cast(params, @optional_params ++ @required_params)
      |> validate_required(@required_params)
  end
end
