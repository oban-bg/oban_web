defmodule Oban.Web.Resolver do
  @moduledoc """
  A behavior and default implementation for dashboard value resolution.
  """

  @type user :: nil | map() | struct()
  @type access :: :all | :read_only | [access_option()]
  @type access_option ::
          {:pause_queues, boolean()}
          | {:scale_queues, boolean()}
          | {:cancel_jobs, boolean()}
          | {:delete_jobs, boolean()}
          | {:retry_jobs, boolean()}
  @type refresh :: 1 | 2 | 5 | 15 | -1

  @doc """
  Lookup or extract a user from a `Plug.Conn`.
  """
  @callback resolve_user(Plug.Conn.t()) :: user()

  @doc """
  Determine the appropriate access level for a user.
  """
  @callback resolve_access(user()) :: access()

  @doc """
  Determine the initial refresh rate when the dashboard mounts.
  """
  @callback resolve_refresh(user()) :: refresh()

  @optional_callbacks resolve_user: 1, resolve_access: 1, resolve_refresh: 1

  @doc false
  def resolve_user(_conn), do: nil

  @doc false
  def resolve_access(_user), do: :all

  @doc false
  def resolve_refresh(_user), do: 1
end
