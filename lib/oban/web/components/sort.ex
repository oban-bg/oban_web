defmodule Oban.Web.Components.Sort do
  use Oban.Web, :html

  def header_link(assigns) do
    ~H"""
    <.link
      patch={sort_link(@label, @page, @params)}
      rel="sort"
      title={title(@label, @params.sort_by, @params.sort_dir)}
      class={"flex justify-#{@justify}"}
    >
      <%= if active_sort?(@label, @params.sort_by) do %>
        <%= if @params.sort_dir == "asc" do %>
          <Icons.bars_arrow_up class="w-4 h-4" />
        <% else %>
          <Icons.bars_arrow_down class="w-4 h-4" />
        <% end %>
      <% else %>
        <div class="w-4 h-4"></div>
      <% end %>

      <span class="pl-1">{@label}</span>
    </.link>
    """
  end

  defp sort_link(label, page, %{sort_by: by, sort_dir: dir} = params) do
    params =
      params
      |> Map.put(:sort_by, String.replace(label, " ", "_"))
      |> Map.put(:sort_dir, new_dir(label, by, dir))

    oban_path(page, params)
  end

  defp title(label, by, dir), do: "Sort by #{label}, #{new_dir(label, by, dir)}"

  defp new_dir(label, by, dir) do
    if active_sort?(label, by) and dir == "asc" do
      "desc"
    else
      "asc"
    end
  end

  defp active_sort?("rate" <> _, "rate_limit"), do: true
  defp active_sort?(label, by), do: label == to_string(by)
end
