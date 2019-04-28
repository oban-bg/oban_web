defmodule ObanWeb.Query do
  @moduledoc false

  import Ecto.Query

  alias Oban.Job

  @queues ~w(default)
  @states ~w(executing available scheduled retryable discarded completed)

  def jobs(repo, opts) when is_map(opts), do: jobs(repo, Keyword.new(opts))

  def jobs(repo, opts) do
    queue = Keyword.get(opts, :queue, "any")
    state = Keyword.get(opts, :state, "executing")
    limit = Keyword.get(opts, :limit, 50)

    Job
    |> filter_state(state)
    |> filter_queue(queue)
    |> order_state(state)
    |> limit(^limit)
    |> repo.all()
  end

  defp filter_state(query, state), do: where(query, state: ^state)

  defp filter_queue(query, "any"), do: query
  defp filter_queue(query, queue), do: where(query, queue: ^queue)

  defp order_state(query, state) when state in ~w(retryable scheduled) do
    order_by(query, [j], desc: j.scheduled_at)
  end

  defp order_state(query, _state) do
    order_by(query, [j], asc: j.attempted_at)
  end

  def queue_counts(queues \\ @queues, repo) do
    counted =
      Job
      |> group_by([j], j.queue)
      |> select([j], {j.queue, count(j.id)})
      |> where(state: "available")
      |> repo.all()
      |> Map.new()

    for queue <- queues, into: %{}, do: {queue, Map.get(counted, queue, 0)}
  end

  def state_counts(states \\ @states, repo) do
    counted =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> repo.all()
      |> Map.new()

    for state <- states, into: %{}, do: {state, Map.get(counted, state, 0)}
  end
end
