# Customizing the Dashboard

Dashboard customization is done through a callback module that implements the
`Oban.Web.Resolver` behaviour. Each of the callback functions are optional and
will fall back to the default implementation, which is shown here as a starting
point:

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
  def format_job_args(%Job{args: args}) do
    inspect(args, charlists: :as_lists, pretty: true)
  end

  @impl true
  def format_job_meta(%Job{meta: meta}) do
    inspect(meta, charlists: :as_lists, pretty: true)
  end
end
```

Jump to details for each of the callbacks:

* [resolve_user/1](#current-user)
* [resolve_access/1](#action-controls)
* [resolve_refresh/1](#default-refresh)
* [format_job_args/1](#formatting-args)
* [format_meta_args/1](#formatting-meta)

### Typespecs

_📚 In order to bridge the gap between module level docs and a guide, here are
the types and callbacks for the Resolver module._

```elixir
@type user :: nil | map()
@type access :: :all | :read_only | [access_option()]
@type access_option ::
        {:pause_queues, boolean()}
        | {:scale_queues, boolean()}
        | {:cancel_jobs, boolean()}
        | {:delete_jobs, boolean()}
        | {:retry_jobs, boolean()}
@type refresh :: 1 | 2 | 5 | 15 | -1

@callback format_job_args(Job.t()) :: String.t()
@callback format_job_meta(Job.t()) :: String.t()
@callback resolve_user(Plug.Conn.t()) :: user()
@callback resolve_access(user()) :: access()
@callback resolve_refresh(user()) :: refresh()
```

## Current User

With the `resolve_user/1` callback you can extract the current user from a
`Plug.Conn` when the dashboard mounts. The extracted user is passed to all of
the other callback functions, allowing you to customize the dashboard per user
or role.

In a typical plug based auth system the current user is stashed the `private`
map:

```elixir
@impl true
def resolve_user(conn) do
  conn.private.current_user
end
```

The `resolve_user/1` callback is expected to return `nil`, a map or a struct.
However, the resolved user is only passed to other functions in the `Resolver`
and as part of the metadata for audit events, so you're free to use any data
type you like.

## Action Controls

During normal operation users can modify running queues and interact with jobs
through the dashboard. In some situations actions such as pausing a queue may be
undesired, or even dangerous for operations.

Through the `resolve_access/1` callback you can tailor precisely which actions
the current user can do. The default access level is `:all`, which permits _all_
users to do any action.

To set the dashboard read only and prevent users from performing any actions at
all:

```elixir
@impl true
def resolve_access(_user), do: :read_only
```

Alternatively, you can use the resolved `user` to allow admins write access and
keep all other users read only:

```elixir
@impl true
def resolve_access(user) do
  if user.admin?, do: :all, else: :read_only
end
```

You can also specify fine grained access for each of the possible dashboard
actions:

```elixir
@impl true
def resolve_access(user) do
  if user.admin? do
    [cancel_jobs: true, delete_jobs: true, retry_jobs: true]
  else
    :read_only
  end
end
```

This configuration allows admins to cancel jobs, delete jobs and retry jobs.
They still can't pause or scale queues because **actions which aren't listed are
considered disabled**.

The available fine grained access controls are:

* `:pause_queues`
* `:scale_queues`
* `:cancel_jobs`
* `:delete_jobs`
* `:retry_jobs`

## Default Refresh

The refresh rate controls how frequently the server pulls statistics from the
database, and when data is pushed from the server. The default refresh rate is 1
second, but you can customize it with a `resolve_refresh/0` callback.

For example, to set the default refresh to 5 seconds:

```elixir
@impl true
def resolve_refresh(_user), do: 5
```

Possible values are: `1`, `2`, `5`, `15` or `-1` to disable refreshing.

Note that this only sets the default. Users may still choose a different refresh
for themselves while viewing the dashboard.

## Formatting Args

By default, all `args` are displayed in full in the table and detail views. If
you desire more control, i.e. for for privacy or brevity, there is the
`format_job_args/1` callback.

For example, to redact the `"email"` for only the `SecretJob` worker:

```elixir
@impl true
def format_job_args(%Oban.Job{worker: "MyApp.SecretJob", args: args}) do
  args
  |> Map.replace("email", "REDACTED")
  |> inspect(pretty: true)
end

def format_job_args(job), do: Oban.Web.Resolver.format_job_args(job)
```

## Formatting Meta

Similarly to `args`, you can format `meta` using the `format_job_meta/1`
callback. Here we're using the callback to mask the `batch_id` for some secret
batch jobs:

```elixir
@impl Oban.Web.Resolver
def format_job_meta(%Oban.Job{meta: %{"batch_id" => _batch} = meta}) do
  meta
  |> Map.replace("batch_id", "SECRET BATCHES")
  |> inspect(pretty: true)
end

def format_job_meta(job), do: Oban.Web.Resolver.format_job_meta(job)
```
