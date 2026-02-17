defmodule Oban.Web.Jobs.HistoryChartComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="group relative">
      <div
        id="job-history-chart"
        class="h-48 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
        phx-hook="JobHistoryChart"
        phx-update="ignore"
        data-current-job-id={@job.id}
      >
      </div>
      <.link
        navigate={all_jobs_path(@job)}
        class="absolute right-4 top-4 flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:bg-blue-100 hover:text-blue-600 dark:hover:bg-blue-900 dark:hover:text-blue-300 opacity-0 group-hover:opacity-100 transition-opacity"
      >
        View all jobs <Icons.arrow_right class="w-3 h-3" />
      </.link>
    </div>
    """
  end

  defp all_jobs_path(job) do
    worker = Map.get(job.meta, "worker", job.worker)
    oban_path(:jobs, %{workers: [worker], state: "completed"})
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> push_chart_data()

    {:ok, socket}
  end

  defp push_chart_data(socket) do
    %{job: job, history: history} = socket.assigns

    chart_data =
      Enum.map(history, fn hist_job ->
        %{
          id: hist_job.id,
          timestamp: timestamp_for(hist_job),
          wait_time: wait_time_for(hist_job),
          exec_time: exec_time_for(hist_job),
          state: hist_job.state,
          current: hist_job.id == job.id
        }
      end)

    push_event(socket, "job-history", %{history: chart_data})
  end

  defp timestamp_for(job) do
    datetime = job.completed_at || job.cancelled_at || job.discarded_at || job.attempted_at || job.scheduled_at

    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  defp exec_time_for(job) do
    case {job.attempted_at, finished_at(job)} do
      {nil, _} -> 0
      {_, nil} -> 0
      {attempted_at, finished_at} -> NaiveDateTime.diff(finished_at, attempted_at, :millisecond)
    end
  end

  defp wait_time_for(job) do
    case job.attempted_at do
      nil -> 0
      attempted_at -> NaiveDateTime.diff(attempted_at, job.scheduled_at, :millisecond)
    end
  end

  defp finished_at(job) do
    job.completed_at || job.cancelled_at || job.discarded_at
  end
end
