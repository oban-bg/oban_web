defmodule Oban.Web.QueryTest do
  use Oban.Web.DataCase, async: true

  alias Oban.{Config, Job}
  alias Oban.Web.{Query, Repo}

  @conf Config.new(repo: Repo)

  describe "all_jobs/2" do
    @tag :search
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

    test "ordering fields by state" do
      ago = fn sec -> DateTime.add(DateTime.utc_now(), -sec) end

      job_a = insert(Alpha, %{}, state: "cancelled", cancelled_at: ago.(4))
      job_b = insert(Alpha, %{}, state: "cancelled", cancelled_at: ago.(6))
      job_c = insert(Alpha, %{}, state: "cancelled", cancelled_at: ago.(1))

      assert [job_b.id, job_a.id, job_c.id] ==
               @conf
               |> Query.all_jobs(%{state: "cancelled"})
               |> Enum.map(& &1.id)

      assert [job_c.id, job_a.id, job_b.id] ==
               @conf
               |> Query.all_jobs(%{state: "cancelled", sort_dir: "desc"})
               |> Enum.map(& &1.id)
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
    |> Query.all_jobs(%{terms: terms, state: "available"})
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end
end
