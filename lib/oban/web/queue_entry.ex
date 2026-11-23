defmodule Oban.Web.QueueEntry do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  schema "oban_queues" do
    field :opts, :map
    field :lock_version, :integer, default: 1

    timestamps(type: :utc_datetime_usec)
  end

  def paused_changeset(entry, paused?) when is_boolean(paused?) do
    entry
    |> change(opts: Map.put(entry.opts, "paused", paused?))
    |> optimistic_lock(:lock_version)
  end
end
