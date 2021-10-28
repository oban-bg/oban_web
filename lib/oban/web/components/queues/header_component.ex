defmodule Oban.Web.Queues.HeaderComponent do
  use Phoenix.Component

  import Oban.Web.Helpers, only: [oban_path: 3]

  def sort_link(assigns) do
    ~H"""
    <%= live_patch(
      to: sort_link(@socket, @label, @params),
      rel: "sort",
      title: title(@label, @params.sort_by, @params.sort_dir),
      class: "flex justify-#{@justify}") do %>
      <%= if active_sort?(@label, @params.sort_by) do %>
        <%= if @params.sort_dir == "asc" do %>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12"></path></svg>
        <% else %>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4h13M3 8h9m-9 4h9m5-4v12m0 0l-4-4m4 4l4-4"></path></svg>
        <% end %>
      <% else %>
        <div class="w-4 h-4"></div>
      <% end %>

      <span class="pl-1"><%= @label %></span>
    <% end %>
    """
  end

  defp sort_link(socket, label, %{sort_by: by, sort_dir: dir} = params) do
    params =
      params
      |> Map.put(:sort_by, String.replace(label, " ", "_"))
      |> Map.put(:sort_dir, new_dir(label, by, dir))

    oban_path(socket, :queues, params)
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
