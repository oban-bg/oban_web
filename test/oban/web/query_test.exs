defmodule Oban.Web.QueryTest do
  use Oban.Web.DataCase, async: true

  alias Oban.{Config, Job}
  alias Oban.Web.{Query, Repo}

  @conf Config.new(repo: Repo)

  describe "get_jobs/2" do
    test "searching for jobs by worker" do
      job_a = insert(MyApp.Alpha)
      job_b = insert(MyApp.Delta)
      job_c = insert(MyApp.Gamma)

      assert search_ids("alpha") == [job_a.id]
      assert search_ids("delta") == [job_b.id]
      assert search_ids("gamma") == [job_c.id]
      assert search_ids("myapp") == [job_a.id, job_b.id, job_c.id]
    end

    @tag :search
    test "searching for jobs by args" do
      job_a = insert(Alpha, %{email: "parker@sorentwo.com", name: "Parker"})
      job_b = insert(Alpha, %{email: "shannon@sorentwo.com", name: "Shannon"})
      job_c = insert(Alpha, %{email: "keaton@example.com", name: "Keaton"})

      assert search_ids("parker@sorentwo.com") == [job_a.id]
      assert search_ids("shannon@sorentwo.com") == [job_b.id]
      assert search_ids("email") == [job_a.id, job_b.id, job_c.id]
      assert search_ids("parker or shannon") == [job_a.id, job_b.id]
      assert search_ids("keaton and shannon") == []
    end

    @tag :search
    test "searching for jobs by tags" do
      job_a = insert(Alpha, %{}, tags: ["gamma"])
      job_b = insert(Alpha, %{}, tags: ["gamma", "delta"])
      job_c = insert(Alpha, %{}, tags: ["delta", "kappa", "omega"])

      assert search_ids("gamma") == [job_a.id, job_b.id]
      assert search_ids("delta") == [job_b.id, job_c.id]
      assert search_ids("delta and gamma") == [job_b.id]
      assert search_ids("delta or kappa") == [job_b.id, job_c.id]
    end
  end

  defp insert(worker, args \\ %{}, opts \\ []) do
    opts = Keyword.put(opts, :worker, worker)

    args
    |> Job.new(opts)
    |> Repo.insert!()
  end

  defp search_ids(terms) do
    @conf
    |> Query.get_jobs(%{terms: terms, state: "available"})
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end
end
