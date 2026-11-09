defmodule Oban.Web.QueueQueryTest do
  use ExUnit.Case, async: true

  alias Oban.Web.{Queue, QueueQuery}

  describe "order/2 by rate limit" do
    test "summing usage for each rate limit algorithm" do
      sliding = [%{"curr_count" => 3, "prev_count" => 2}]
      fixed = [%{"count" => 4}]
      bucket = [%{"consumed" => 6}]

      assert 5 == QueueQuery.order(queue(sliding), :rate_limit)
      assert 4 == QueueQuery.order(queue(fixed), :rate_limit)
      assert 6 == QueueQuery.order(queue(bucket), :rate_limit)
    end

    test "summing across checks and ignoring those without a rate limit" do
      queue = %Queue{
        name: "alpha",
        checks: [
          %{"rate_limit" => %{"windows" => [%{"curr_count" => 1, "prev_count" => 1}]}},
          %{"rate_limit" => %{"windows" => [%{"count" => 3}]}},
          %{"local_limit" => 5}
        ]
      }

      assert 5 == QueueQuery.order(queue, :rate_limit)
    end
  end

  defp queue(windows) do
    %Queue{name: "alpha", checks: [%{"rate_limit" => %{"windows" => windows}}]}
  end
end
