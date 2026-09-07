defmodule Oban.Web.ColorsTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Colors

  describe "series_colors/1" do
    test "a label keeps its color regardless of which other labels are present" do
      solo = Colors.series_colors(["mailers"])
      pair = Colors.series_colors(["mailers", "events"])
      trio = Colors.series_colors(["analysis", "mailers", "events"])

      assert solo["mailers"] == pair["mailers"]
      assert pair["mailers"] == trio["mailers"]
      assert pair["events"] == trio["events"]
    end

    test "labels never share a color while the palette has room" do
      labels = ~w(alpha beta gamma delta epsilon zeta eta)
      colors = Colors.series_colors(labels)

      assert map_size(colors) == 7
      assert colors |> Map.values() |> Enum.uniq() |> length() == 7
    end

    test "every assigned color resolves to a hex and a register away from the state palette" do
      for {_label, name} <- Colors.series_colors(~w(alpha beta gamma)) do
        assert Colors.series_hex(name) =~ ~r/^#[0-9a-f]{6}$/
        assert Colors.series_bg_class(name) =~ ~r/^bg-(\w+)-600 dark:bg-\1-300$/
      end
    end
  end
end
