defmodule Oban.Web.Repo.Migrations.UpgradeObanVersionTo2 do
  use Ecto.Migration

  defdelegate up, to: Oban.Migrations
  defdelegate down, to: Oban.Migrations
end
