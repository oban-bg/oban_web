defmodule Oban.Web.Assets do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  phoenix_js_paths =
    for app <- ~w(phoenix phoenix_html phoenix_live_view)a do
      path = Application.app_dir(app, ["priv", "static", "#{app}.js"])
      Module.put_attribute(__MODULE__, :external_resource, path)
      path
    end

  @static_path Application.app_dir(:oban_web, ["priv", "static"])

  @external_resource css_path = Path.join(@static_path, "app.css")
  @external_resource js_path = Path.join(@static_path, "app.js")

  @css File.read!(css_path)

  @js """
  #{for path <- phoenix_js_paths, do: path |> File.read!() |> String.replace("//# sourceMappingURL=", "// ")}
  #{File.read!(js_path)}
  """

  @impl Plug
  def init(asset), do: asset

  @impl Plug
  def call(conn, asset) do
    {contents, content_type} = contents_and_type(asset)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, contents)
    |> halt()
  end

  defp contents_and_type(:css), do: {@css, "text/css"}
  defp contents_and_type(:js), do: {@js, "text/javascript"}

  for {key, val} <- [css: @css, js: @js] do
    md5 = Base.encode16(:crypto.hash(:md5, val), case: :lower)

    def current_hash(unquote(key)), do: unquote(md5)
  end
end
