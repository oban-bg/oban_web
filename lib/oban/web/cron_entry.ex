defmodule Oban.Web.CronEntry do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:name, :string, autogenerate: false}
  schema "oban_crons" do
    field :expression, :string
    field :worker, :string
    field :opts, :map
    field :insertions, {:array, :utc_datetime_usec}, default: []
    field :paused, :boolean, default: false
    field :lock_version, :integer, default: 1

    field :inserted_at, :utc_datetime_usec
    field :updated_at, :utc_datetime_usec
  end
end
