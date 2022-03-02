defmodule Mix.Tasks.Web.Docs.Publish do
  @shortdoc "Publish docs to getoban.pro"

  @moduledoc false

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, []} = OptionParser.parse(args, strict: [release_token: :string])

    build()
    sync()
    invalidate(opts)
  end

  defp build do
    Mix.Task.run("docs")
  end

  defp sync do
    docs_path = "s3://repo-oban-pro/docs/web"

    Mix.shell().cmd("aws s3 sync doc #{docs_path} --cache-control 'public; max-age=604800'")
  end

  defp invalidate(opts) do
    token = Keyword.fetch!(opts, :release_token)
    url = "https://getoban.pro/webhooks/release"
    auth_header = "Authorization: Bearer #{token}"

    Mix.shell().cmd("curl -I -X POST -H '#{auth_header}' #{url}")
  end
end
