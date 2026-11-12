defmodule Oban.Web.CronEntry do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oban.Cron.Expression

  @primary_key {:name, :string, autogenerate: false}
  schema "oban_crons" do
    field :expression, :string
    field :worker, :string
    field :opts, :map
    field :insertions, {:array, :utc_datetime_usec}, default: []
    field :paused, :boolean, default: false
    field :lock_version, :integer, default: 1

    timestamps(type: :utc_datetime_usec)
  end

  @permitted ~w(name expression worker opts paused)a
  @required ~w(name expression worker)a
  @allowed_opts ~w(args guaranteed max_attempts meta priority queue tags timezone)

  def changeset(entry \\ %__MODULE__{}, params) do
    entry
    |> cast(params, @permitted)
    |> validate_required(@required)
    |> validate_change(:expression, &validate_expression/2)
    |> validate_change(:opts, &validate_opts/2)
    |> reset_insertions()
    |> optimistic_lock(:lock_version)
  end

  def timezone(%{opts: %{"timezone" => timezone}}), do: timezone
  def timezone(_entry), do: nil

  defp validate_expression(:expression, expression) do
    case Expression.parse(expression) do
      {:ok, _parsed} -> []
      {:error, _error} -> [expression: "expected cron expression to be a parsable binary"]
    end
  end

  defp validate_opts(:opts, opts) do
    if Enum.all?(opts, fn {key, _value} -> to_string(key) in @allowed_opts end) do
      []
    else
      [opts: "expected cron opts to be one of #{inspect(@allowed_opts)}"]
    end
  end

  defp reset_insertions(changeset) do
    stored = timezone(changeset.data)
    latest = timezone(%{opts: get_field(changeset, :opts)})

    if changed?(changeset, :expression) or stored != latest do
      put_change(changeset, :insertions, [])
    else
      changeset
    end
  end
end
