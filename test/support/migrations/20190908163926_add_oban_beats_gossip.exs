defmodule ObanWeb.Repo.Migrations.AddObanBeatsGossip do
  use Ecto.Migration

  def up do
    ObanWeb.Migrations.up(version: 2)
  end

  def down do
    ObanWeb.Migrations.down(version: 2)
  end
end
