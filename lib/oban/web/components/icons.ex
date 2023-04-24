defmodule Oban.Web.Components.Icons do
  use Oban.Web, :html

  # Helpers

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
    <svg xmlns="http://www.w3.org/2000/svg" {@rest}>
      <%= render_slot(@inner_block) %>
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
      <%= render_slot(@inner_block) %>
    </svg>
    """
  end

  # Icons

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

  def check(assigns) do
    ~H"""
    <.svg_outline {@rest}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
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
        d="M14.25 9v6m-4.5 0V9M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
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
end
