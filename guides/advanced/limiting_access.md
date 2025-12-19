# Limiting Access

Oban Web provides flexible access control through the `Oban.Web.Resolver` behaviour. This guide
covers how to restrict dashboard access and control which actions users can perform.

## How Access Control Works

Access control follows a two-step process when the dashboard mounts:

1. **Extract User** — The `c:Oban.Web.Resolver.resolve_user/1` callback extracts the current user
   from the `Plug.Conn`. User resolution is optional, and only required if you want to customize
   access at the user level.

2. **Resolve Access** — The `c:Oban.Web.Resolver.resolve_access/1` callback determines what
   actions the user can do based on their identity, role, etc.

For example, here is a resolver that pulls the `current_user` out of assigns, then scopes access
by the user's role:

```elixir
defmodule MyApp.Resolver do
  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_user(conn) do
    conn.assigns[:current_user]
  end

  @impl true
  def resolve_access(user) do
    case user do
      %{role: :admin} -> :all
      %{role: :viewer} -> :read_only
      _ -> {:forbidden, "/"}
    end
  end
end
```

To use the resolver, pass it to `oban_dashboard/2` in your router:

```elixir
scope "/" do
  pipe_through :browser

  oban_dashboard "/oban", resolver: MyApp.Resolver
end
```

## Access Levels

The `resolve_access/1` callback can return four different access levels:

### Full Access

Return `:all` to grant full access to all dashboard operations:

```elixir
def resolve_access(%{admin?: true}), do: :all
```

### Read Only

Return `:read_only` to allow viewing the dashboard without any modification capabilities:

```elixir
def resolve_access(_user), do: :read_only
```

In read-only mode, users can view jobs, queues, and metrics but cannot pause queues, cancel jobs,
or perform any other actions.

### Fine-Grained Control

Return a keyword list to enable specific actions while keeping everything else disabled:

```elixir
def resolve_access(user) do
  if user.can_manage_jobs? do
    [cancel_jobs: true, delete_jobs: true, retry_jobs: true]
  else
    :read_only
  end
end
```

The available fine-grained actions are:

| Action          | Description                            |
| --------------- | -------------------------------------- |
| `:pause_queues` | Pause and resume queues                |
| `:scale_queues` | Change queue concurrency               |
| `:stop_queues`  | Stop queues entirely                   |
| `:cancel_jobs`  | Cancel running or scheduled jobs       |
| `:delete_jobs`  | Permanently delete jobs                |
| `:retry_jobs`   | Retry failed or discarded jobs         |

Actions not listed in the keyword list are considered disabled. For example, this configuration
allows job management but prevents any queue operations:

```elixir
def resolve_access(_user) do
  [cancel_jobs: true, delete_jobs: true, retry_jobs: true]
end
```

### Forbidden Access

Return `{:forbidden, path}` to deny access entirely and redirect the user:

```elixir
def resolve_access(nil), do: {:forbidden, "/login"}
def resolve_access(%{banned?: true}), do: {:forbidden, "/banned"}
def resolve_access(_user), do: :all
```

The user will see a flash message indicating they don't have access and be redirected to the
specified path.

## Integration Patterns

### With Plug-Based Authentication

Most authentication libraries store the current user in `conn.assigns`. Here's how to integrate
with common patterns:

```elixir
defmodule MyApp.Resolver do
  @behaviour Oban.Web.Resolver

  # Works with Pow, Guardian assigns, or any plug that sets current_user
  @impl true
  def resolve_user(conn) do
    conn.assigns[:current_user]
  end

  @impl true
  def resolve_access(nil), do: {:forbidden, "/login"}
  def resolve_access(%{role: "admin"}), do: :all
  def resolve_access(%{role: "operator"}), do: [pause_queues: true, retry_jobs: true]
  def resolve_access(_user), do: :read_only
end
```

### With Session-Based Authentication

If your user is stored in the session rather than assigns:

```elixir
@impl true
def resolve_user(conn) do
  Plug.Conn.get_session(conn, :current_user)
end
```

### Role-Based Access Control

Map user roles to appropriate access levels:

```elixir
@impl true
def resolve_access(%{role: role}) do
  case role do
    :super_admin -> :all
    :admin -> [pause_queues: true, scale_queues: true, cancel_jobs: true, retry_jobs: true]
    :support -> [cancel_jobs: true, retry_jobs: true]
    :developer -> :read_only
    _ -> {:forbidden, "/"}
  end
end
```

### Environment-Based Restrictions

Restrict access based on environment to prevent accidental modifications in production:

```elixir
@impl true
def resolve_access(user) do
  if Application.get_env(:my_app, :env) == :prod do
    if user.super_admin?, do: :all, else: :read_only
  else
    :all
  end
end
```

## Combining with Basic Auth

For simple protection without a full authentication system, combine the resolver with Basic Auth
at the router level:

```elixir
import Plug.BasicAuth

pipeline :admin do
  plug :basic_auth, username: "admin", password: "secret"
end

scope "/" do
  pipe_through [:browser, :admin]

  oban_dashboard "/oban"
end
```

Or use environment variables for credentials:

```elixir
pipeline :admin do
  plug :basic_auth,
    username: System.fetch_env!("OBAN_USERNAME"),
    password: System.fetch_env!("OBAN_PASSWORD")
end
```

## Audit Logging

All dashboard actions emit telemetry events that can be used for audit logging. Attach the
built-in logger to capture user activity:

```elixir
# In your application startup
Oban.Web.Telemetry.attach_default_logger()
```

This logs actions with the resolved user, making it easy to track who performed what operations.
See `Oban.Web.Telemetry` for more details on customizing telemetry handling.
