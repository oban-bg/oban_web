defmodule Oban.Web.Beat do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "oban_beats" do
    field :node, :string
    field :queue, :string
    field :nonce, :string
    field :limit, :integer
    field :paused, :boolean, default: false
    field :running, {:array, :integer}, default: []
    field :inserted_at, :utc_datetime_usec
    field :started_at, :utc_datetime_usec
  end
end
