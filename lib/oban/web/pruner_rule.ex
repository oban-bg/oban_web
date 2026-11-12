defmodule Oban.Web.PrunerRule do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @max_limit 10_000_000

  @primary_key {:name, :string, autogenerate: false}
  schema "oban_pruners" do
    field :position, :integer
    field :archive, :boolean, default: false
    field :paused, :boolean, default: false
    field :limit, :integer, default: 10_000
    field :timeout, :integer, default: 60_000
    field :hash, :string
    field :lock_version, :integer, default: 1

    embeds_one :match, Match, on_replace: :update, primary_key: false do
      @moduledoc false

      field :queue, :string
      field :worker, :string
      field :state, :string
    end

    embeds_one :mode, Mode, on_replace: :update, primary_key: false do
      @moduledoc false

      field :kind, Ecto.Enum, values: [:max_age, :max_len]
      field :value, :string
    end

    timestamps(type: :utc_datetime_usec)
  end

  def max_limit, do: @max_limit

  def changeset(rule \\ %__MODULE__{}, params) do
    rule
    |> cast(params, ~w(archive limit name paused position timeout)a)
    |> cast_embed(:match, with: &cast(&1, &2, ~w(queue worker state)a))
    |> cast_embed(:mode, with: &cast(&1, &2, ~w(kind value)a))
    |> validate_number(:limit, greater_than: 0, less_than_or_equal_to: @max_limit)
    |> validate_number(:timeout, greater_than: 0)
    |> optimistic_lock(:lock_version)
  end

  def lock_changeset(rule) do
    rule
    |> change()
    |> optimistic_lock(:lock_version)
  end
end
