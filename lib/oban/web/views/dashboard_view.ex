defmodule Oban.Web.DashboardView do
  use Oban.Web, :view

  alias Oban.Web.IconView

  @doc """
  A helper for rendering icon templates from the IconView.
  """
  def icon(name) do
    render(IconView, name <> ".html")
  end

  @clearable_filter_types [:node, :queue, :worker]
  def clearable_filters(filters) do
    for {type, name} <- filters, type in @clearable_filter_types, name != "any" do
      {to_string(type), name}
    end
  end
end
