defmodule ObanWeb.Repo.Migrations.AddObanJobsSearchIndexes do
  use Ecto.Migration

  defdelegate up, to: ObanWeb.Migrations
  defdelegate down, to: ObanWeb.Migrations
end
