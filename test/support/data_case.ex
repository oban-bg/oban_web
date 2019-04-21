defmodule ObanWeb.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias ObanWeb.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ObanWeb.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ObanWeb.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(ObanWeb.Repo, {:shared, self()})
    end

    :ok
  end
end
