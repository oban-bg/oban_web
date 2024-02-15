defmodule Oban.Web.Resolver do
  @moduledoc """
  Web customization is done through a callback module that implements the this behaviour.

  ## Usage

  Each callback is optional and resolution falls back to the default implementation when a
  callback is omittied. Here is an example implementation that defines all callbacks with their
  default values for reference:

  ```elixir
  defmodule MyApp.Resolver do
    @behaviour Oban.Web.Resolver

    @impl true
    def resolve_user(_conn), do: nil

    @impl true
    def resolve_access(_user), do: :all

    @impl true
    def resolve_refresh(_user), do: 1

    @impl true
    def format_job_args(%Oban.Job{args: args}) do
      inspect(args, charlists: :as_lists, pretty: true)
    end

    @impl true
    def format_job_meta(%Oban.Job{meta: meta}) do
      inspect(meta, charlists: :as_lists, pretty: true)
    end

    @impl true
    def format_recorded(recorded, _job) do
      recorded
      |> Oban.Web.Resolver.decode_recorded()
      |> inspect(charlists: :as_lists, pretty: true)
    end

    @impl true
    def jobs_query_limit(_state), do: 100_000

    @impl true
    def hint_query_limit(_qualifier), do: 10_000
  end
  ```

  To use a resolver such as `MyApp.Resolver` defined above, you pass it through as an option to
  `oban_dashboard/2` in your application's router:

  ```elixir
  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban", resolver: MyApp.Resolver
  end
  ```

  ## Overview

  Details about each callback's functionality can be found in the callback docs. Here's a quick
  summary of each callback and its purpose:

  * [Current User](#c:resolve_user/1)—Extract the current user for access controls when the
  dashboard mounts.

  * [Action Controls](#c:resolve_access/1)—Restrict which operations users may perform or forbid
  access to the dashboard.

  * [Jobs Query Limit](#c:jobs_query_limit/1)—Control the maximum number of jobs to query when
  filtering, searching, and otherwise listing jobs.

  * [Hint Query Limit](#c:hint_query_limit/1)—Control the maximum number of jobs to search for
  auto-complete hints.

  * [Format Job Args](#c:format_job_args/1)—Override the default verbose args formatting.

  * [Format Job Meta](#c:format_meta_args/1)—Override the default verbose meta formatting.

  * [Default Refresh](#c:resolve_refresh/1)—Set the default refresh interval for new sessions.

  ## Authentication

  By combining `resolver_user/1` and `resolve_access/1` callbacks it's possible to build an
  authenticaiton solution around the dashboard. For example, this resolver extracts the
  `current_user` from the conn's assigns map and then scopes their access based on role. If it is
  a standard user or `nil` then they're redirected to `/login` when the dashboard mounts.

  ```elixir
  defmodule MyApp.Resolver do
    @behaviour Oban.Web.Resolver

    @impl true
    def resolve_user(conn) do
      conn.assigns.current_user
    end

    @impl true
    def resolve_access(user) do
      case user do
        %{admin?: true} -> :all
        %{staff?: true} -> :read_only
        _ -> {:forbidden, "/login"}
      end
    end
  end
  ```
  """

  alias Oban.Job

  @type access :: :all | :read_only | [access_option()] | {:forbidden, Path.t()}

  @type access_option :: :pause_queues | :scale_queues | :cancel_jobs | :delete_jobs | :retry_jobs

  @type qualifier :: :args | :meta | :nodes | :queues | :tags | :workers

  @type refresh :: 1 | 2 | 5 | 15 | 60 | -1

  @type user :: term()

  @doc """
  Customize the formatting of job args wherever they are displayed.

  This callback allows for full over args formatting; whether for privacy, brevity, or clarity. By
  default, all `args` are preserved in table and detail views.

  ## Examples

  Redact the `"email"` field for only the `SecretJob` worker:

      def format_job_args(%Oban.Job{worker: "MyApp.SecretJob", args: args}) do
        args
        |> Map.replace("email", "REDACTED")
        |> inspect(pretty: true)
      end

      def format_job_args(job), do: Oban.Web.Resolver.format_job_args(job)
  """
  @callback format_job_args(job :: Job.t()) :: iodata()

  @doc """
  Customize the formatting of job meta wherever it is displayed.

  This callback behaves identically to `c:format_job_args/1`, but is used for `meta`.

  ## Examples

  Msk the `batch_id` for some secret batch jobs:

      def format_job_meta(%Oban.Job{meta: %{"batch_id" => _batch} = meta}) do
        meta
        |> Map.replace("batch_id", "SECRET BATCHES")
        |> inspect(pretty: true)
      end

      def format_job_meta(job), do: Oban.Web.Resolver.format_job_meta(job)
  """
  @callback format_job_meta(job :: Job.t()) :: iodata()

  @doc """
  Customize the formatting of recorded output wherever it is displayed.

  This callback is similar to `c:format_job_args/1`, but it accepts both the recorded binary and
  the job to help augment the output.

  Note that you **must decode the recorded binary** prior to inspecting it.

  ## Examples

  Disable pretty printing and change the output width to 98 characters:

      def format_recorded(recorded, _job) do
        recorded
        |> Oban.Web.Resolver.decode_recorded()
        |> inspect(pretty: false, width: 98)
      end

  Decode the recorded value without the `:safe` flag set, to allow decoding terms with unknown
  atoms:

      def format_recorded(recorded, _job) do
        recorded
        |> Oban.Web.Resolver.decode_recorded([])
        |> inspect(pretty: false, width: 98)
      end

  Display job args alongside recorded output:

      def format_recorded(recorded, %Oban.Job{args: args}) when is_map(recorded) do
        recorded
        |> Oban.Web.Resolver.decode_recorded()
        |> Map.put(:args, args)
        |> inspect(charlists: :as_lists, pretty: true)
      end
  """
  @callback format_recorded(recorded :: term(), job :: Job.t()) :: iodata()

  @doc """
  Extract the current user from a `Plug.Conn` when the dashboard mounts.

  The extracted user is passed to all of the other callback functions, allowing you to customize the
  dashboard per user or role.

  This callback is expected to return `nil`, a map or a struct. However, the resolved user is only
  passed to other functions in the `Resolver` and as part of the metadata for audit events, so
  you're free to use any data type you like.

  ## Examples

  Extract the user from the `assigns` map in a typical plug based auth setup:

      def resolve_user(conn) do
        conn.assigns.current_user
      end

  """
  @callback resolve_user(conn :: Plug.Conn.t()) :: user()

  @doc """
  Determine the appropriate access level for a user.

  During normal operation users can modify running queues and interact with jobs through the
  dashboard. In some situations actions such as pausing a queue may be undesired, or even
  dangerous for operations.

  Through this callback you can tailor precisely which actions the current user can do. The
  default access level is `:all`, which permits _all_ users to do any action.

  Returning `{:forbidden, path}` prevents loading the dashboard entirely and redirects the user to
  the provided path.

  The available fine grained access controls are:

  * `:pause_queues`
  * `:scale_queues`
  * `:cancel_jobs`
  * `:delete_jobs`
  * `:retry_jobs`

  Actions which aren't listed are considered disabled.

  ## Examples

  To set the dashboard read only and prevent users from performing any actions at all:

      def resolve_access(_user), do: :read_only

  Forbid any user that isn't an admin and redirect them to the root:

      def resolve_access(user) do
        if user.admin?, do: :all, else: {:forbidden, "/"}
      end

  Alternatively, you can use the resolved `user` to allow admins write access and keep all other
  users read only:

      def resolve_access(user) do
        if user.admin?, do: :all, else: :read_only
      end

  You can also specify fine grained access for each of the possible dashboard actions.

      def resolve_access(user) do
        if user.admin? do
          [cancel_jobs: true, delete_jobs: true, retry_jobs: true]
        else
          :read_only
        end
      end
  """
  @callback resolve_access(user()) :: access()

  @doc """
  Determine the initial refresh rate when the dashboard mounts.

  The refresh rate controls how frequently the server pulls statistics from the database, and when
  data is pushed from the server. The default refresh rate is 1 second.

  Possible values are: `1`, `2`, `5`, `15` or `-1` to disable refreshing.

  Note that this only sets the default. Users may still choose a different refresh for themselves
  while viewing the dashboard and their chosen value will stick for future sessions.

  ## Examples

  Default to 5 seconds:

      def resolve_refresh(_user), do: 5
  """
  @callback resolve_refresh(user()) :: refresh()

  @doc """
  The maximum number of jobs to query when displaying jobs.

  Ordering is applied _after_ limiting the query. That means the "oldest" job displayed will
  always be within the filter limit. For example, with a limit of 100k jobs and 200k completed
  jobs, only the latest 100k are queryable and the oldest 100k are effectively invisible.

  In the interest of speed, limits are only approximate.

  The limit may be determined by state, e.g. `:completed` or `:cancelled`, to fine-tune query
  performance for larger states. Limiting may be disabled with `:infinity`.

  Without a callback impleted, the `:completed` state defaults to a conservative 100k jobs and all
  other states are `:infinite`.

  ## Example

  Restrict the limit for all states:

      def jobs_query_limit(_qualifier), do: 50_000

  Use a conservative the limit for `:completed` without any limit for other states (this is the
  default):

      def jobs_query_limit(:completed), do: 100_000
      def jobs_query_limit(_state), do: :infinity
  """
  @callback jobs_query_limit(Job.unique_state()) :: :infinity | pos_integer()

  @doc """
  The maximum number of jobs to query for auto-complete suggestions.

  The limit may be determined by qualifier, e.g. `:args` or `:worker`, to fine-tune the impact of
  suggestion queries. Limiting may be disabled with `:infinity`.

  Without a callback implemented it defaults to 10,000 for all qualifiers.

  ## Example

  Increase the limit to 20k for all qualifiers:

      def hint_query_limit(_qualifier), do: 20_000

  Customize the limit for `args` and `meta`, falling back to 10k for everything else.

      def hint_query_limit(:args), do: 5_000
      def hint_query_limit(:meta), do: 2_000
      def hint_query_limit(_qualifier), do: 10_000
  """
  @callback hint_query_limit(qualifier()) :: :infinity | pos_integer()

  @optional_callbacks format_job_args: 1,
                      format_job_meta: 1,
                      format_recorded: 2,
                      hint_query_limit: 1,
                      jobs_query_limit: 1,
                      resolve_user: 1,
                      resolve_access: 1,
                      resolve_refresh: 1

  @inspect_opts [charlists: :as_lists, pretty: true]

  @doc """
  Decode a recorded job's output from a compressed, base64 binary into proper terms.

  By default, decoding uses the `:safe` flag to prevent decoding unsafe data that can be used to
  attack the Erlang runtime.

  ## Example

  Decode a recorded binary:

      iex> Oban.Web.Resolver.decode_recorded("g3QAAAABdwRuYW1lbQAAAARvYmFu")
      %{name: "oban"}

  Decode without safety:

      iex> Oban.Web.Resolver.decode_recorded("g3QAAAABdwRhdG9tdwd1bmtub3du", [])
      %{atom: :unknown}
  """
  @spec decode_recorded(binary(), [:safe]) :: term()
  def decode_recorded(bin, opts \\ [:safe]) do
    bin
    |> Base.decode64!(padding: false)
    |> :erlang.binary_to_term(opts)
  end

  @doc false
  def format_job_args(%Job{args: args}), do: inspect(args, @inspect_opts)

  @doc false
  def format_job_meta(%Job{meta: meta}), do: inspect(meta, @inspect_opts)

  @doc false
  def format_recorded(recorded, _job) do
    recorded
    |> decode_recorded()
    |> inspect(@inspect_opts)
  end

  @doc false
  def resolve_user(_conn), do: nil

  @doc false
  def resolve_access(_user), do: :all

  @doc false
  def resolve_refresh(_user), do: 1

  @doc false
  def jobs_query_limit(:completed), do: 100_000
  def jobs_query_limit(_state), do: :infinity

  @doc false
  def hint_query_limit(_qualifier), do: 10_000
end
