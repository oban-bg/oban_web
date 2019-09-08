defmodule ObanWeb.Repo.Migrations.AddObanJobsSearchIndexes do
  use Ecto.Migration

  def up do
    ObanWeb.Migrations.up(version: 1)
  end

  def down do
    ObanWeb.Migrations.down(version: 1)
  end
end
