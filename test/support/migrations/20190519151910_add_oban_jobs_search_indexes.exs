defmodule Oban.Web.Repo.Migrations.AddObanJobsSearchIndexes do
  use Ecto.Migration

  def up do
    Oban.Web.Migrations.up(version: 1)
  end

  def down do
    Oban.Web.Migrations.down(version: 1)
  end
end
