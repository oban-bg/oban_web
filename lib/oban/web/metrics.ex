defmodule Oban.Web.Metrics do
  @moduledoc false

  alias Oban.Met

  @states ~w(available executing scheduled retryable)a

  @doc """
  Fetch latest metric counts with optional fallback to previous values.

  When `Met.latest/3` returns an empty map (which happens when the reporter's
  `check_interval` exceeds the recorder's lookback window), this function
  returns the `previous` value instead. This prevents UI flickering in the
  sidebar when metrics briefly show as zero between reporter broadcasts.
  """
  def latest(name, series, opts \\ [], previous \\ %{}) do
    result = Met.latest(name, series, opts)

    if result == %{} and previous != %{} do
      previous
    else
      result
    end
  end

  @doc """
  Fetch state counts for the jobs sidebar.
  """
  def state_counts(name, ordered_states, previous \\ []) do
    counts = latest(name, :full_count, [group: "state"], counts_to_map(previous))

    if counts == %{} and previous != [] do
      previous
    else
      for state <- ordered_states do
        %{name: state, count: Map.get(counts, state, 0)}
      end
    end
  end

  defp counts_to_map(previous) when is_list(previous) do
    Map.new(previous, fn %{name: name, count: count} -> {name, count} end)
  end

  defp counts_to_map(previous), do: previous

  @doc """
  Fetch queue counts for a specific state.
  """
  def queue_counts(name, state, previous \\ %{}) do
    latest(name, :full_count, [group: "queue", filters: [state: to_string(state)]], previous)
  end

  @doc """
  Fetch state counts filtered by queue for queue detail view.
  """
  def queue_state_counts(name, queue, previous \\ %{}) do
    latest(name, :full_count, [group: "state", filters: [queue: queue]], previous)
  end

  @doc """
  Fetch counts for all queue states needed for the queues sidebar.
  """
  def all_queue_counts(name, previous \\ %{}) do
    Map.new(@states, fn state ->
      {state, queue_counts(name, state, previous[state])}
    end)
  end

  @doc """
  Extract previous counts from a list of queue structs for caching.
  """
  def extract_queue_counts(queues) when is_list(queues) do
    for state <- @states, into: %{} do
      per_queue =
        for queue <- queues, into: %{}, do: {queue.name, Map.get(queue.counts, state, 0)}

      {state, per_queue}
    end
  end

  def extract_queue_counts(_), do: %{}
end
