defmodule Oban.Web.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migration.up()
    Oban.Migration.up(prefix: "private")
  end
  
  def down do
    Oban.Migration.down()
    Oban.Migration.down(prefix: "private")
  end
end
