defmodule Oban.Web.DolphinRepo.Migrations.AddOban do
  use Ecto.Migration

  defdelegate up, to: Oban.Migration
  defdelegate down, to: Oban.Migration
end
