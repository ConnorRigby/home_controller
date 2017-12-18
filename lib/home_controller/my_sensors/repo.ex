defmodule HomeController.MySensors.Repo do
  @moduledoc "Repo for MySensors data."
  use Ecto.Repo,
    otp_app: :home_controller,
    adapter: Sqlite.Ecto2
end
