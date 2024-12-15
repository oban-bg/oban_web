defmodule Oban.Web.Components.Icons do
  use Oban.Web, :html

  # Helpers

  attr :rest, :global,
    default: %{
      "aria-hidden": "true",
      class: "w-4 h-4",
      fill: "currentColor",
      viewBox: "0 0 16 16"
    }

  slot :inner_block, required: true

  defp svg_mini(assigns) do
    ~H"""
    <svg {@rest}>
      {render_slot(@inner_block)}
    </svg>
    """
  end

  attr :rest, :global,
    default: %{
      "stroke-width": "1.5",
      class: "w-6 h-6",
      fill: "none",
      stroke: "currentColor",
      viewBox: "0 0 24 24"
    }

  slot :inner_block, required: true

  defp svg_outline(assigns) do
    ~H"""
    <svg {@rest}>
      {render_slot(@inner_block)}
    </svg>
    """
  end

  attr :rest, :global,
    default: %{
      "aria-hidden": "true",
      class: "w-6 h-6",
      fill: "currentColor",
      viewBox: "0 0 24 24"
    }

  slot :inner_block, required: true

  defp svg_solid(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" {@rest}>
      {render_slot(@inner_block)}
    </svg>
    """
  end

  # Icons

  attr :rest, :global

  def adjustments_horizontal(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def adjustments_vertical(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M6 13.5V3.75m0 9.75a1.5 1.5 0 010 3m0-3a1.5 1.5 0 000 3m0 3.75V16.5m12-3V3.75m0 9.75a1.5 1.5 0 010 3m0-3a1.5 1.5 0 000 3m0 3.75V16.5m-6-9V3.75m0 3.75a1.5 1.5 0 010 3m0-3a1.5 1.5 0 000 3m0 9.75V10.5"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def arrow_left(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def arrow_path(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def arrow_path_rounded(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M19.5 12c0-1.232-.046-2.453-.138-3.662a4.006 4.006 0 00-3.7-3.7 48.678 48.678 0 00-7.324 0 4.006 4.006 0 00-3.7 3.7c-.017.22-.032.441-.046.662M19.5 12l3-3m-3 3l-3-3m-12 3c0 1.232.046 2.453.138 3.662a4.006 4.006 0 003.7 3.7 48.656 48.656 0 007.324 0 4.006 4.006 0 003.7-3.7c.017-.22.032-.441.046-.662M4.5 12l3 3m-3-3l-3 3"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def arrow_right_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12.75 15l3-3m0 0l-3-3m3 3h-7.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def arrow_top_right_on_square(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def arrow_trending_down(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M2.25 6L9 12.75l4.286-4.286a11.948 11.948 0 014.306 6.43l.776 2.898m0 0l3.182-5.511m-3.182 5.51l-5.511-3.181"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def calendar_days(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5m-9-6h.008v.008H12v-.008zM12 15h.008v.008H12V15zm0 2.25h.008v.008H12v-.008zM9.75 15h.008v.008H9.75V15zm0 2.25h.008v.008H9.75v-.008zM7.5 15h.008v.008H7.5V15zm0 2.25h.008v.008H7.5v-.008zm6.75-4.5h.008v.008h-.008v-.008zm0 2.25h.008v.008h-.008V15zm0 2.25h.008v.008h-.008v-.008zm2.25-4.5h.008v.008H16.5v-.008zm0 2.25h.008v.008H16.5V15z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def crossbones_circle(assigns) do
    ~H"""
    <.svg_solid {@rest}>
      <path d="M12 2c5.523 0 10 4.478 10 10 0 5.523-4.477 10-10 10-5.522 0-10-4.477-10-10C2 6.478 6.478 2 12 2Zm0 1.363a8.637 8.637 0 1 0 0 17.274 8.637 8.637 0 1 0 0-17.274Zm4.358 11.077a.625.625 0 0 1-.344.814l-2.374.965 2.375.967a.625.625 0 0 1 .37.733l-.027.08a.625.625 0 0 1-.815.344l-3.56-1.45-3.558 1.45a.625.625 0 0 1-.472-1.158l2.373-.966-2.373-.965a.625.625 0 0 1-.37-.733l.027-.081a.625.625 0 0 1 .814-.344l3.559 1.449 3.56-1.449c.32-.13.684.024.815.344ZM12.023 5.61c2.16 0 3.913 1.546 3.864 3.455 0 1.257-.743 2.348-1.877 2.952l.149.699c.071.341-.146.672-.448.672h-3.424c-.298 0-.494-.33-.423-.672l.125-.697c-1.111-.605-1.878-1.697-1.878-2.976 0-1.886 1.753-3.433 3.913-3.433Zm1.435 1.945a.975.975 0 0 0-.973.972c0 .535.437.972.973.972a.973.973 0 0 0 0-1.944Zm-2.917 0a.993.993 0 0 0-.972.972c0 .535.41.972.973.972a.958.958 0 0 0 .972-.972.974.974 0 0 0-.972-.972h-.001Z" />
    </.svg_solid>
    """
  end

  attr :rest, :global

  def bars_arrow_down(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M3 4.5h14.25M3 9h9.75M3 13.5h9.75m4.5-4.5v12m0 0l-3.75-3.75M17.25 21L21 17.25"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def bars_arrow_up(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M3 4.5h14.25M3 9h9.75M3 13.5h5.25m5.25-.75L17.25 9m0 0L21 12.75M17.25 9v12"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def bolt_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M13.317 6.066a.648.648 0 0 1 .337.703l-.683 3.517h3.404c.245 0 .467.147.568.375a.657.657 0 0 1-.096.688l-5.416 6.43a.613.613 0 0 1-.747.155.648.648 0 0 1-.338-.702l.683-3.518H7.625a.624.624 0 0 1-.568-.375.657.657 0 0 1 .096-.688l5.416-6.43a.613.613 0 0 1 .748-.155ZM21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def bolt_slash(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M11.412 15.655 9.75 21.75l3.745-4.012M9.257 13.5H3.75l2.659-2.849m2.048-2.194L14.25 2.25 12 10.5h8.25l-4.707 5.043M8.457 8.457 3 3m5.457 5.457 7.086 7.086m0 0L21 21"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def camera(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"
      />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def chart_bar_square(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M7.5 14.25v2.25m3-4.5v4.5m3-6.75v6.75m3-9v9M6 20.25h12A2.25 2.25 0 0020.25 18V6A2.25 2.25 0 0018 3.75H6A2.25 2.25 0 003.75 6v12A2.25 2.25 0 006 20.25z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def check(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def check_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def check_empty(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        d="M3.455 19h13.09A2.455 2.455 0 0 0 19 16.545V3.455A2.455 2.455 0 0 0 16.545 1H3.455A2.455 2.455 0 0 0 1 3.455v13.09A2.455 2.455 0 0 0 3.455 19Z"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def check_partial_solid(assigns) do
    ~H"""
    <.svg_solid {@rest}>
      <path d="M17.273 0A2.727 2.727 0 0 1 20 2.727v14.546A2.727 2.727 0 0 1 17.273 20H2.727A2.727 2.727 0 0 1 0 17.273V2.727A2.727 2.727 0 0 1 2.727 0ZM15 9H5a1 1 0 1 0 0 2h10a1 1 0 0 0 0-2Z" />
    </.svg_solid>
    """
  end

  attr :rest, :global

  def check_selected(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <g stroke-linecap="round" stroke-linejoin="round">
        <path d="M3.455 19h13.09A2.455 2.455 0 0 0 19 16.545V3.455A2.455 2.455 0 0 0 16.545 1H3.455A2.455 2.455 0 0 0 1 3.455v13.09A2.455 2.455 0 0 0 3.455 19Z" />
        <path d="m5 11 4 4 6-9" />
      </g>
    </.svg_outline>
    """
  end

  attr :rest, :global

  def check_selected_solid(assigns) do
    ~H"""
    <.svg_solid {@rest}>
      <path d="M17.273 0A2.727 2.727 0 0 1 20 2.727v14.546A2.727 2.727 0 0 1 17.273 20H2.727A2.727 2.727 0 0 1 0 17.273V2.727A2.727 2.727 0 0 1 2.727 0Zm-1.857 5.376a.75.75 0 0 0-1.04.208l-5.493 8.238L5.53 10.47a.75.75 0 0 0-1.06 1.06l4 4a.75.75 0 0 0 1.154-.114l6-9a.75.75 0 0 0-.208-1.04Z" />
    </.svg_solid>
    """
  end

  attr :rest, :global

  def chevron_down(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def chevron_right(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def chevron_up(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5" />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def clock(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def cog(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M4.5 12a7.5 7.5 0 0015 0m-15 0a7.5 7.5 0 1115 0m-15 0H3m16.5 0H21m-1.5 0H12m-8.457 3.077l1.41-.513m14.095-5.13l1.41-.513M5.106 17.785l1.15-.964m11.49-9.642l1.149-.964M7.501 19.795l.75-1.3m7.5-12.99l.75-1.3m-6.063 16.658l.26-1.477m2.605-14.772l.26-1.477m0 17.726l-.26-1.477M10.698 4.614l-.26-1.477M16.5 19.794l-.75-1.299M7.5 4.205L12 12m6.894 5.785l-1.149-.964M6.256 7.178l-1.15-.964m15.352 8.864l-1.41-.513M4.954 9.435l-1.41-.514M12.002 12l-3.75 6.495"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def command_line(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M6.75 7.5l3 2.25-3 2.25m4.5 0h3m-9 8.25h13.5A2.25 2.25 0 0021 18V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v12a2.25 2.25 0 002.25 2.25z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def computer_desktop(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25m18 0A2.25 2.25 0 0018.75 3H5.25A2.25 2.25 0 003 5.25m18 0V12a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 12V5.25"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def exclamation_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def globe(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def info_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def hashtag(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M5.25 8.25h15m-16.5 7.5h15m-1.8-13.5l-3.9 19.5m-2.1-19.5l-3.9 19.5"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def life_buoy(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M16.712 4.33a9.027 9.027 0 0 1 1.652 1.306c.51.51.944 1.064 1.306 1.652M16.712 4.33l-3.448 4.138m3.448-4.138a9.014 9.014 0 0 0-9.424 0M19.67 7.288l-4.138 3.448m4.138-3.448a9.014 9.014 0 0 1 0 9.424m-4.138-5.976a3.736 3.736 0 0 0-.88-1.388 3.737 3.737 0 0 0-1.388-.88m2.268 2.268a3.765 3.765 0 0 1 0 2.528m-2.268-4.796a3.765 3.765 0 0 0-2.528 0m4.796 4.796c-.181.506-.475.982-.88 1.388a3.736 3.736 0 0 1-1.388.88m2.268-2.268 4.138 3.448m0 0a9.027 9.027 0 0 1-1.306 1.652c-.51.51-1.064.944-1.652 1.306m0 0-3.448-4.138m3.448 4.138a9.014 9.014 0 0 1-9.424 0m5.976-4.138a3.765 3.765 0 0 1-2.528 0m0 0a3.736 3.736 0 0 1-1.388-.88 3.737 3.737 0 0 1-.88-1.388m2.268 2.268L7.288 19.67m0 0a9.024 9.024 0 0 1-1.652-1.306 9.027 9.027 0 0 1-1.306-1.652m0 0 4.138-3.448M4.33 16.712a9.014 9.014 0 0 1 0-9.424m4.138 5.976a3.765 3.765 0 0 1 0-2.528m0 0c.181-.506.475-.982.88-1.388a3.736 3.736 0 0 1 1.388-.88m-2.268 2.268L4.33 7.288m6.406 1.18L7.288 4.33m0 0a9.024 9.024 0 0 0-1.652 1.306A9.025 9.025 0 0 0 4.33 7.288"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def lock_closed(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def map_pin(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def magnifying_glass(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def minus_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M15 12H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def moon(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path d="M17.715 15.15A6.5 6.5 0 0 1 9 6.035C6.106 6.922 4 9.645 4 12.867c0 3.94 3.153 7.136 7.042 7.136 3.101 0 5.734-2.032 6.673-4.853Z">
      </path>
    </.svg_outline>
    """
  end

  attr :rest, :global

  def no_symbol(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def pause_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M14.25 9v6m-4.5 0V9M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def pause_circle_solid(assigns) do
    ~H"""
    <.svg_solid {@rest}>
      <path
        fill-rule="evenodd"
        d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12ZM9 8.25a.75.75 0 0 0-.75.75v6c0 .414.336.75.75.75h.75a.75.75 0 0 0 .75-.75V9a.75.75 0 0 0-.75-.75H9Zm5.25 0a.75.75 0 0 0-.75.75v6c0 .414.336.75.75.75H15a.75.75 0 0 0 .75-.75V9a.75.75 0 0 0-.75-.75h-.75Z"
        clip-rule="evenodd"
      />
    </.svg_solid>
    """
  end

  attr :rest, :global

  def percent_square(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        d="M6 4h12.5a2 2 0 0 1 2 2v12.5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Zm2 13 9-9m-6.313 2.125a.563.563 0 1 1-1.125 0 .563.563 0 0 1 1.126 0Zm4.75 4.75a.562.562 0 1 1-1.124 0 .562.562 0 0 1 1.124 0Z"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def play_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M15.91 11.672a.375.375 0 0 1 0 .656l-5.603 3.113a.375.375 0 0 1-.557-.328V8.887c0-.286.307-.466.557-.327l5.603 3.112Z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def play_circle_solid(assigns) do
    ~H"""
    <.svg_solid {@rest}>
      <path
        fill-rule="evenodd"
        d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12Zm14.024-.983a1.125 1.125 0 0 1 0 1.966l-5.603 3.113A1.125 1.125 0 0 1 9 15.113V8.887c0-.857.921-1.4 1.671-.983l5.603 3.113Z"
        clip-rule="evenodd"
      />
    </.svg_solid>
    """
  end

  attr :rest, :global

  def play_pause_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        d="M17 9v6m-2.455-6v6M7 14.32V9.68c0-.494.509-.803.918-.558l3.877 2.32c.191.115.31.328.31.559 0 .23-.119.443-.31.558l-3.877 2.32a.59.59 0 0 1-.613-.002.65.65 0 0 1-.305-.556h0ZM12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def plus_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 9v6m3-3H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def queue_list(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def soren_logo(assigns) do
    ~H"""
    <.svg_solid {@rest}>
      <path
        fill-rule="evenodd"
        d="M18 3.315a.251.251 0 00-.073-.177l-1.065-1.065a.25.25 0 00-.353 0l-1.772 1.773a7.766 7.766 0 00-10.89 10.89L2.072 16.51a.251.251 0 000 .352l1.066 1.066a.25.25 0 00.352 0l1.773-1.772a7.766 7.766 0 0010.89-10.891l1.773-1.773A.252.252 0 0018 3.315zM5.474 10c0-1.21.471-2.345 1.326-3.2A4.496 4.496 0 0110 5.474c.867 0 1.697.243 2.413.695l-6.244 6.244A4.495 4.495 0 015.474 10zm9.052 0c0 1.209-.471 2.345-1.326 3.2a4.496 4.496 0 01-3.2 1.326 4.497 4.497 0 01-2.413-.695l6.244-6.244c.452.716.695 1.546.695 2.413z"
      />
    </.svg_solid>
    """
  end

  attr :rest, :global

  def square_stack(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L21.75 12l-4.179 2.25m0 0l4.179 2.25L12 21.75 2.25 16.5l4.179-2.25m11.142 0l-5.571 3-5.571-3"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def square_2x2(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def rectangle_group(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M2.25 7.125C2.25 6.504 2.754 6 3.375 6h6c.621 0 1.125.504 1.125 1.125v3.75c0 .621-.504 1.125-1.125 1.125h-6a1.125 1.125 0 01-1.125-1.125v-3.75zM14.25 8.625c0-.621.504-1.125 1.125-1.125h5.25c.621 0 1.125.504 1.125 1.125v8.25c0 .621-.504 1.125-1.125 1.125h-5.25a1.125 1.125 0 01-1.125-1.125v-8.25zM3.75 16.125c0-.621.504-1.125 1.125-1.125h5.25c.621 0 1.125.504 1.125 1.125v2.25c0 .621-.504 1.125-1.125 1.125h-5.25a1.125 1.125 0 01-1.125-1.125v-2.25z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def spinner(assigns) do
    ~H"""
    <svg viewBox="0 0 100 101" fill="none" {@rest}>
      <path
        d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
        fill="currentColor"
      />
      <path
        d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
        fill="currentFill"
      />
    </svg>
    """
  end

  attr :rest, :global

  def table_cells(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h7.5c.621 0 1.125-.504 1.125-1.125m-9.75 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m18.375 2.625V5.625m0 12.75c0 .621-.504 1.125-1.125 1.125m1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125m0 3.75h-7.5A1.125 1.125 0 0112 18.375m9.75-12.75c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125m19.5 0v1.5c0 .621-.504 1.125-1.125 1.125M2.25 5.625v1.5c0 .621.504 1.125 1.125 1.125m0 0h17.25m-17.25 0h7.5c.621 0 1.125.504 1.125 1.125M3.375 8.25c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125m17.25-3.75h-7.5c-.621 0-1.125.504-1.125 1.125m8.625-1.125c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125M12 10.875v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 10.875c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125M13.125 12h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125M20.625 12c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5M12 14.625v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 14.625c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125m0 1.5v-1.5m0 0c0-.621.504-1.125 1.125-1.125m0 0h7.5"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def sun(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def trash(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def user_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def x_circle(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </.svg_outline>
    """
  end

  attr :rest, :global

  def x_mark(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
    </.svg_outline>
    """
  end
end
