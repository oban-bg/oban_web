defmodule ObanWeb.Query do
  @moduledoc false

  import Ecto.Query

  def jobs(repo, opts \\ []) do
    state = Keyword.get(opts, :state, "executing")
    limit = Keyword.get(opts, :limit, 200)

    Oban.Job
    |> filter_state(state)
    |> order_state(state)
    |> limit(^limit)
    |> repo.all()
  end

  defp filter_state(query, "scheduled") do
    query
    |> where([j], j.state == "available")
    |> where([j], j.attempt == 0 and j.scheduled_at > ^DateTime.utc_now())
  end

  defp filter_state(query, "retryable") do
    query
    |> where([j], j.state == "available")
    |> where([j], j.attempt > 0 and j.scheduled_at > ^DateTime.utc_now())
  end

  defp filter_state(query, state) do
    where(query, state: ^state)
  end

  defp order_state(query, state) when state in ~w(retryable scheduled) do
    order_by(query, [j], desc: j.scheduled_at)
  end

  defp order_state(query, _state) do
    order_by(query, [j], asc: j.attempted_at)
  end

  def queue_counts(queues, repo) do
    counted =
      Oban.Job
      |> group_by([j], j.queue)
      |> select([j], {j.queue, count(j.id)})
      |> where(state: "available")
      |> repo.all()
      |> Map.new()

    for {queue, limit} <- queues, into: %{} do
      queue = to_string(queue)
      count = Map.get(counted, queue, 0)

      {queue, {count, limit}}
    end
  end

  @state_query """
  with estimate as (
    select reltuples::bigint as total from pg_class where relname = 'oban_jobs'
  ), others as (
    select (select count(*) from oban_jobs where state = 'executing') +
           (select count(*) from oban_jobs where state = 'available') +
           (select count(*) from oban_jobs where state = 'discarded') as total
  )

  select (select count(*) from oban_jobs where state = 'executing') as executing,
         (select count(*) from oban_jobs where state = 'available' and scheduled_at < (now() at time zone 'utc')) as available,
         (select count(*) from oban_jobs where state = 'available' and attempt = 0 and scheduled_at > (now() at time zone 'utc')) as scheduled,
         (select count(*) from oban_jobs where state = 'available' and attempt > 0 and scheduled_at > (now() at time zone 'utc')) as retryable,
         (select count(*) from oban_jobs where state = 'discarded') as discarded,
         (select (select total from estimate) - (select total from others)) as completed;
  """
  def state_counts(repo) do
    {:ok, %{columns: states, rows: [counts]}} = repo.query(@state_query)

    Enum.zip(states, counts)
  end
end
