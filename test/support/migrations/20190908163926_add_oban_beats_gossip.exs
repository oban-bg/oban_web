defmodule Oban.Web.Repo.Migrations.AddObanBeatsGossip do
  use Ecto.Migration

  def up do
    Oban.Web.Migrations.up(version: 2)
  end

  def down do
    Oban.Web.Migrations.down(version: 2)
  end
end
