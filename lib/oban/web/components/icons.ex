defmodule Oban.Web.Components.Icons do
  @moduledoc false

  use Phoenix.Component

  @icons_path Application.app_dir(:oban_web, ["priv", "static", "icons"])

  @outline_path Path.join(@icons_path, "outline")
  @solid_path Path.join(@icons_path, "solid")

  @outline_icons @outline_path
                 |> File.ls!()
                 |> Enum.filter(&String.ends_with?(&1, ".svg"))
                 |> Enum.map(&String.trim_trailing(&1, ".svg"))

  @solid_icons @solid_path
               |> File.ls!()
               |> Enum.filter(&String.ends_with?(&1, ".svg"))
               |> Enum.map(&String.trim_trailing(&1, ".svg"))

  for icon <- @outline_icons do
    @external_resource Path.join(@outline_path, "#{icon}.svg")

    func_name = icon |> String.replace("-", "_") |> String.to_atom()

    @doc false
    attr :class, :any, default: "w-6 h-6"
    attr :rest, :global

    def unquote(func_name)(assigns) do
      assigns = assign(assigns, :icon_path, "outline/#{unquote(icon)}.svg")

      render_icon(assigns)
    end
  end

  for icon <- @solid_icons do
    @external_resource Path.join(@solid_path, "#{icon}.svg")

    func_name =
      icon
      |> String.replace("-", "_")
      |> Kernel.<>("_solid")
      |> String.to_atom()

    @doc false
    attr :class, :any, default: "w-6 h-6"
    attr :rest, :global

    def unquote(func_name)(assigns) do
      assigns = assign(assigns, :icon_path, "solid/#{unquote(icon)}.svg")

      render_icon(assigns)
    end
  end

  # Inline Icons

  attr :rest, :global, default: %{class: "w-6 h-6"}

  def oban_pro_logo(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" {@rest}>
      <g fill="none" fill-rule="evenodd">
        <path d="m463.6 169.99-26.62-95.01-95-26.62 35.61 86z" fill="#e3f3fb" /><path
          d="M427.97 256 377.6 134.36l86 35.62z"
          fill="#99c5d4"
        /><path d="m437 74.96 26.61 95 28.87-11.95a256.25 256.25 0 0 0-55.47-83z" fill="#4e7eac" /><path
          d="M492.48 158.01a256.25 256.25 0 0 1 19.5 97.96l-48.37-86z"
          fill="#16495e"
        /><path d="m463.61 341.97 48.36-86-48.36-86-35.62 86z" fill="#ace6ea" /><path
          d="M377.6 377.6 428 255.97l35.62 86z"
          fill="#b6d6e8"
        /><path d="m512 255.97-48.36 86 28.86 11.96A256.25 256.25 0 0 0 511.97 256z" fill="#406484" /><path
          d="M492.5 353.93a256.25 256.25 0 0 1-55.48 83.05l26.62-95z"
          fill="#5b84a6"
        /><path d="m342.01 463.6 95.01-26.62 26.62-95-86 35.61z" fill="#9bc4e4" /><path
          d="m256 427.97 121.63-50.38-35.62 86z"
          fill="#506882"
        /><path d="m437.04 437-95 26.61 11.95 28.87a256.25 256.25 0 0 0 83-55.47z" fill="#3c6a91" /><path
          d="M353.99 492.48a256.25 256.25 0 0 1-97.96 19.5l86-48.37z"
          fill="#1d4268"
        /><path d="m170.03 463.61 86 48.36 86-48.36-86-35.62z" fill="#4d87b9" /><path
          d="M134.4 377.6 256.03 428l-86 35.62z"
          fill="#6588a8"
        /><path d="m256.03 512-86-48.36-11.96 28.86A256.24 256.24 0 0 0 256 511.97z" fill="#156a90" /><path
          d="M158.07 492.5a256.25 256.25 0 0 1-83.05-55.48l95.01 26.62z"
          fill="#316087"
        /><path d="m48.4 342.01 26.62 95.01 95.01 26.62-35.62-86z" fill="#417bb1" /><path
          d="m84.03 256 50.38 121.63-86-35.62z"
          fill="#87bdd7"
        /><path d="m75 437.04-26.61-95-28.87 11.95a256.25 256.25 0 0 0 55.47 83z" fill="#284963" /><path
          d="M19.52 353.99a256.25 256.25 0 0 1-19.5-97.96l48.37 86z"
          fill="#467baa"
        /><path d="m48.39 170.03-48.36 86 48.36 86 35.62-86z" fill="#7fadd0" /><path
          d="M134.4 134.4 84 256.03l-35.62-86z"
          fill="#abcae7"
        /><path d="m0 256.03 48.36-86-28.86-11.96A256.24 256.24 0 0 0 .03 256z" fill="#94c0ce" /><path
          d="M19.5 158.07a256.24 256.24 0 0 1 55.48-83.05l-26.62 95.01z"
          fill="#b3d6e2"
        /><path d="M169.99 48.4 74.98 75.02l-26.62 95.01 86-35.62z" fill="#e7fafa" /><path
          d="M256 84.03 134.36 134.4l35.62-86z"
          fill="#aed4f0"
        /><path d="m74.96 75 95-26.61-11.95-28.87a256.24 256.24 0 0 0-83 55.47z" fill="#c6dde5" /><path
          d="M158.01 19.52A256.25 256.25 0 0 1 255.97.02l-86 48.37z"
          fill="#a9d5e9"
        /><path d="m341.97 48.39-86-48.36-86 48.36 86 35.62z" fill="#f8ffff" /><path
          d="M377.6 134.4 255.97 84l86-35.62z"
          fill="#c2e8f8"
        /><path d="m255.97 0 86 48.36 11.96-28.86A256.25 256.25 0 0 0 256 .03z" fill="#bedee6" /><path
          d="M353.93 19.5a256.25 256.25 0 0 1 83.05 55.48l-95.01-26.62z"
          fill="#9fcff0"
        />
      </g>
    </svg>
    """
  end

  attr :rest, :global, default: %{class: "w-6 h-6"}

  def spinner(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="none" {@rest}>
      <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.5" opacity="0.25" />
      <path d="M12 3a9 9 0 0 1 9 9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
    </svg>
    """
  end

  defp render_icon(assigns) do
    icon_url = icon_url(assigns.icon_path)
    class = normalize_class(assigns.class)
    assigns = assigns |> assign(:icon_url, icon_url) |> assign(:normalized_class, class)

    ~H"""
    <span
      class={["block bg-current", @normalized_class]}
      style={"mask-image: url(#{@icon_url}); -webkit-mask-image: url(#{@icon_url}); mask-size: contain; mask-repeat: no-repeat; mask-position: center;"}
      aria-hidden="true"
      {@rest}
    />
    """
  end

  defp icon_url(path) do
    case Process.get(:routing) do
      {socket, prefix} ->
        Phoenix.VerifiedRoutes.unverified_path(
          socket,
          socket.router,
          "#{prefix}/icons/#{path}"
        )

      _ ->
        "/icons/#{path}"
    end
  end

  defp normalize_class(class) when is_binary(class), do: class
  defp normalize_class(class) when is_list(class), do: class
  defp normalize_class(nil), do: "w-6 h-6"
end
