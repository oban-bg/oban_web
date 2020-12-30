defmodule Oban.Web.Resolver do
  @moduledoc """
  A behavior and default implementation for dashboard value resolution.
  """

  @type user :: nil | map() | struct()
  @type access :: :all | :read | [access_option()]
  @type access_option ::
          {:pause_queues, boolean()}
          | {:scale_queues, boolean()}
          | {:cancel_jobs, boolean()}
          | {:delete_jobs, boolean()}
          | {:retry_jobs, boolean()}

  @doc """
  Lookup or extract a user from a `Plug.Conn`.
  """
  @callback resolve_user(Plug.Conn.t()) :: user()

  @doc """
  Determine the appropriate access level for a user.
  """
  @callback resolve_access(user()) :: access()

  @doc false
  def resolve_user(_conn), do: nil

  @doc false
  def resolve_access(_user), do: :all
end
