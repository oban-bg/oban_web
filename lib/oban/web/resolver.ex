defmodule Oban.Web.Resolver do
  @moduledoc false

  alias Oban.Job

  @type user :: nil | map() | struct()
  @type access :: :all | :read_only | [access_option()]
  @type access_option ::
          {:pause_queues, boolean()}
          | {:scale_queues, boolean()}
          | {:cancel_jobs, boolean()}
          | {:delete_jobs, boolean()}
          | {:retry_jobs, boolean()}
  @type refresh :: 1 | 2 | 5 | 15 | 60 | -1

  @doc """
  Customize the formatting of job args wherever they are displayed.
  """
  @callback format_job_args(Job.t()) :: String.t()

  @doc """
  Customize the formatting of job meta wherever it is displayed.
  """
  @callback format_job_meta(Job.t()) :: String.t()

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

  @optional_callbacks format_job_args: 1,
                      format_job_meta: 1,
                      resolve_user: 1,
                      resolve_access: 1,
                      resolve_refresh: 1

  @doc false
  def format_job_args(%Job{args: args}), do: inspect(args, charlists: :as_lists, pretty: true)

  @doc false
  def format_job_meta(%Job{meta: meta}), do: inspect(meta, charlists: :as_lists, pretty: true)

  @doc false
  def resolve_user(_conn), do: nil

  @doc false
  def resolve_access(_user), do: :all

  @doc false
  def resolve_refresh(_user), do: 1
end
