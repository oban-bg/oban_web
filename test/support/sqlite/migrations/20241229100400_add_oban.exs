defmodule Oban.Web.LiteRepo.Migrations.AddOban do
  use Ecto.Migration

  defdelegate up, to: Oban.Migration
  defdelegate down, to: Oban.Migration
end
