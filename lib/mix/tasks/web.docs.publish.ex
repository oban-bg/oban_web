defmodule Mix.Tasks.Web.Docs.Publish do
  @shortdoc "Publish docs to getoban.pro"

  @moduledoc false

  use Mix.Task

  @bucket_prefix "s3://repo-oban-pro/docs/web"

  @impl Mix.Task
  def run(args) do
    {opts, _, []} = OptionParser.parse(args, strict: [current: :boolean, release_token: :string])

    build()
    publish(opts)
    invalidate(opts)
  end

  defp build do
    Mix.Task.run("docs")
  end

  defp publish(opts) do
    version =
      :oban_web
      |> Application.spec(:vsn)
      |> to_string()

    paths =
      if Keyword.fetch!(opts, :current) do
        [@bucket_prefix, Path.join(@bucket_prefix, version)]
      else
        [Path.join(@bucket_prefix, version)]
      end

    for path <- paths do
      Mix.shell().cmd("aws s3 sync doc #{path} --cache-control 'public; max-age=604800'")
    end
  end

  defp invalidate(opts) do
    token = Keyword.fetch!(opts, :release_token)
    url = "https://getoban.pro/webhooks/release"
    auth_header = "Authorization: Bearer #{token}"

    Mix.shell().cmd("curl -I -X POST -H '#{auth_header}' #{url}")
  end
end
