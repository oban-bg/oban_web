defmodule Oban.Web.Repo do
  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.Postgres

  def reload!(%{__struct__: queryable, id: id}) do
    get!(queryable, id)
  end
end
