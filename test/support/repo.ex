defmodule Oban.Web.Repo do
  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.Postgres
end

defmodule Oban.Web.SQLiteRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.SQLite3
end

defmodule Oban.Web.MyXQLRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.MyXQL
end
