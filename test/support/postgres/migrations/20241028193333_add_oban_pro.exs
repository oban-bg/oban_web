defmodule Oban.Web.Repo.Migrations.AddObanPro do
  use Ecto.Migration

  def up do
    Oban.Pro.Migration.up()
  end

  def down do
    Oban.Pro.Migration.down()
  end
end
