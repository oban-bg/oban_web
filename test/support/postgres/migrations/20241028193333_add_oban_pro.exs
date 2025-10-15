defmodule Oban.Web.Repo.Migrations.AddObanPro do
  use Ecto.Migration

  @compile {:no_warn_undefined, Oban.Pro.Migration}

  def up do
    if Code.ensure_loaded?(Oban.Pro.Migration) do
      Oban.Pro.Migration.up()
      Oban.Pro.Migration.up(prefix: "private")
    end
  end

  def down do
    if Code.ensure_loaded?(Oban.Pro.Migration) do
      Oban.Pro.Migration.down()
      Oban.Pro.Migration.down(prefix: "private")
    end
  end
end
