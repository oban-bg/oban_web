defmodule ObanWeb.Migrations do
  @moduledoc false

  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    create index(:oban_jobs, ["worker gist_trgm_ops"],
             name: :oban_jobs_worker_gist,
             using: "GIST"
           )

    create index(:oban_jobs, ["(to_tsvector('english'::regconfig, args::text))"],
             name: :oban_jobs_args_vector,
             using: "GIN"
           )
  end

  def down do
    drop_if_exists index(:oban_jobs, ["worker"], name: :oban_jobs_worker_gist)
    drop_if_exists index(:oban_jobs, ["args"], name: :oban_jobs_args_vector)
  end
end
