defmodule Oban.Web.Workflow do
  @moduledoc false

  use Ecto.Schema

  @fields ~w(
    id name parent_id inserted_at meta
    suspended available scheduled executing retryable completed cancelled discarded
  )a

  @primary_key {:id, :string, autogenerate: false}
  schema "oban_workflows" do
    field :name, :string
    field :parent_id, :string
    field :state, :string
    field :meta, :map

    field :suspended, :integer, default: 0
    field :available, :integer, default: 0
    field :scheduled, :integer, default: 0
    field :executing, :integer, default: 0
    field :retryable, :integer, default: 0
    field :completed, :integer, default: 0
    field :cancelled, :integer, default: 0
    field :discarded, :integer, default: 0

    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :inserted_at, :utc_datetime_usec
  end

  def changeset(params) do
    Ecto.Changeset.cast(%__MODULE__{}, params, @fields)
  end
end
