defmodule Oban.Web.Repo.Migrations.AddObanPro do
  use Ecto.Migration

  def up do
    Oban.Pro.Migration.up()
    Oban.Pro.Migration.up(prefix: "private")
  end

  def down do
    Oban.Pro.Migration.down()
    Oban.Pro.Migration.down(prefix: "private")
  end
end
