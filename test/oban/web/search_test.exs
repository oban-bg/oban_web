defmodule Oban.Web.SearchTest do
  use Oban.Web.Case, async: true

  alias Oban.Web.Search

  @moduletag :search

  describe "suggest/2" do
    def suggest(terms, name \\ nil) do
      conf = if name, do: Oban.config(name), else: nil

      Search.suggest(terms, conf)
    end

    test "falling back to defaults without a query" do
      assert [{"args:", _, _} | _] = suggest("")
      assert [{"args:", _, _} | _] = suggest("  ")
    end

    test "falling back to defaults without any fragments" do
      assert [{"args:", _, _} | _] = suggest("priority:1 ")
      assert [{"args:", _, _} | _] = suggest("state:available priority:1 ")
    end

    test "suggesting qualifiers with fragments" do
      assert [{"priorities:", _, _}] = suggest("prior")
      assert [{"priorities:", _, _}] = suggest("priorities")
    end

    test "ignoring unsuggestable qualifiers" do
      assert [] = suggest("args:")
      assert [] = suggest("args.id:")
      assert [] = suggest("meta:")
      assert [] = suggest("meta.batch_id:")
      assert [] = suggest("tags:")
    end

    test "suggesting fixed priorities" do
      assert [{"0", _, _} | _] = suggest("priorities:")
      assert [{"0", _, _}] = suggest("priorities:0")
      assert [{"1", _, _}] = suggest("priorities:1")
    end

    test "suggesting fixed states" do
      assert [{"available", _, _} | _] = suggest("state:")
      assert [{"available", _, _}] = suggest("state:a")
      assert [{"available", _, _}] = suggest("state:available")

      assert [{"cancelled", _, _}] = suggest("state:can")
      assert [{"completed", _, _}] = suggest("state:com")
    end

    test "suggesting nodes" do
      name = start_supervised_oban!()

      store_labels(name, "node", "web.1@host")
      store_labels(name, "node", "web.2@host")
      store_labels(name, "node", "loc.8@host")

      assert [{"loc.8@host", _, _}, _, _] = suggest("nodes:", name)
      assert [{"web.1@host", _, _}, {"web.2@host", _, _}] = suggest("nodes:web", name)
      assert [{"web.1@host", _, _}] = suggest("nodes:web.1", name)

      stop_supervised!(name)
    end

    test "suggesting queues" do
      name = start_supervised_oban!()

      store_labels(name, "queue", "alpha")
      store_labels(name, "queue", "gamma")
      store_labels(name, "queue", "delta")

      assert [{"alpha", _, _}, _, _] = suggest("queues:", name)
      assert [{"alpha", _, _}] = suggest("queues:a", name)
      assert [{"delta", _, _}] = suggest("queues:delta", name)

      stop_supervised!(name)
    end

    test "suggesting workers" do
      name = start_supervised_oban!()

      store_labels(name, "worker", "MyApp.Alpha")
      store_labels(name, "worker", "MyApp.Gamma")
      store_labels(name, "worker", "MyApp.Delta")

      assert [{"MyApp.Alpha", _, _}, _, _] = suggest("workers:", name)
      assert [{"MyApp.Alpha", _, _}, _, _] = suggest("workers:My", name)
      assert [{"MyApp.Delta", _, _}] = suggest("workers:MyApp.Delta", name)

      stop_supervised!(name)
    end
  end

  describe "complete/2" do
    def complete(terms) do
      Search.complete(terms, nil)
    end

    test "completing with an unknown qualifier" do
      assert "stuff" == complete("stuff")
    end

    test "completing a qualifier" do
      assert "queues:" == complete("qu")
      assert "queues:" == complete("queue")
      assert "state:" == complete("st")
      assert "state:" == complete("state")
    end

    test "completing a value suggestion" do
      assert "state:available" == complete("state:ava")
    end
  end

  describe "append/2" do
    import Search, only: [append: 2]

    test "appending new qualifiers" do
      assert "queue:" == append("qu", "queue:")
      assert "queue:" == append("queue", "queue:")
      assert "queue:" == append("queue:", "queue:")
      assert "node:web queue:" == append("node:web que", "queue:")
    end

    test "preventing duplicate values" do
      assert "queue:" == append("queue:", "queue:")
    end
  end

  defp store_labels(name, label, value) do
    gauge = Oban.Met.Values.Gauge.new(1)

    name
    |> Oban.Registry.via(Oban.Met.Recorder)
    |> Oban.Met.Recorder.store(:exec_time, gauge, %{label => value})
  end
end
