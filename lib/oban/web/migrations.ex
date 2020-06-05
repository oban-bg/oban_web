defmodule Oban.Web.Migrations do
  @moduledoc false

  use Ecto.Migration

  @initial_version 1
  @current_version 2

  def up(opts \\ []) when is_list(opts) do
    version = Keyword.get(opts, :version, @current_version)

    change(@initial_version..version, :up)
  end

  def down(opts \\ []) when is_list(opts) do
    version = Keyword.get(opts, :version, @initial_version)

    change(@current_version..version, :down)
  end

  defp change(range, direction) do
    for index <- range do
      [__MODULE__, "V#{index}"]
      |> Module.safe_concat()
      |> apply(direction, [])
    end
  end

  defmodule V1 do
    @moduledoc false

    use Ecto.Migration

    def up do
      execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

      create_if_not_exists index(:oban_jobs, ["worker gist_trgm_ops"],
                             name: :oban_jobs_worker_gist,
                             using: "GIST"
                           )

      create_if_not_exists index(:oban_jobs, ["(to_tsvector('simple'::regconfig, args::text))"],
                             name: :oban_jobs_args_vector,
                             using: "GIN"
                           )
    end

    def down do
      drop_if_exists index(:oban_jobs, ["worker"], name: :oban_jobs_worker_gist)
      drop_if_exists index(:oban_jobs, ["args"], name: :oban_jobs_args_vector)
    end
  end

  defmodule V2 do
    @moduledoc false

    use Ecto.Migration

    def up do
      execute """
      CREATE OR REPLACE FUNCTION oban_beats_gossip() RETURNS trigger AS $$
      DECLARE
        channel text;
        notice json;
      BEGIN
        channel = 'public.oban_gossip';
        notice = json_build_object(
          'count', coalesce(array_length(NEW.running, 1), 0),
          'limit', NEW.limit,
          'node', NEW.node,
          'paused', NEW.paused,
          'queue', NEW.queue
        );

        PERFORM pg_notify(channel, notice::text);

        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql
      """

      # Postgres doesn't have a "CREATE OR REPLACE TRIGGER"
      execute "DROP TRIGGER IF EXISTS oban_beats_gossip ON oban_beats"

      execute """
      CREATE TRIGGER oban_gossip
      AFTER INSERT ON oban_beats
      FOR EACH ROW EXECUTE PROCEDURE oban_beats_gossip()
      """
    end

    def down do
      execute "DROP TRIGGER IF EXISTS oban_gossip ON oban_beats"
      execute "DROP FUNCTION IF EXISTS oban_beats_gossip"
    end
  end
end
