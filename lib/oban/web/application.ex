defmodule Oban.Web.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [Oban.Web.Cache]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
