defmodule Oban.Web.Repo do
  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.Postgres
end

defmodule Oban.Web.LiteRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.SQLite3
end

defmodule Oban.Web.DolphinRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.MyXQL
end
