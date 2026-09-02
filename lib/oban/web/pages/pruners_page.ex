defmodule Oban.Web.PrunersPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.{Page, PrunerQuery, SearchComponent, SortComponent, Telemetry, Utils}
  alias Oban.Web.Pruners.{DetailComponent, NewComponent, TableComponent}

  @known_params PrunerQuery.known_params() ++ ~w(sort_by sort_dir)

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="pruners-page" class="w-full my-6">
      <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
        <%= cond do %>
          <% not @pro_available? -> %>
            <.pro_promo />
          <% not @has_pruners? -> %>
            <.migration_prompt conf={@conf} />
          <% @rule -> %>
            <.live_component
              id="detail"
              access={@access}
              configured?={MapSet.member?(@configured_names, @rule.name)}
              module={DetailComponent}
              rule={@rule}
              rules={@rules}
            />
          <% true -> %>
            <div
              id="pruners-header"
              class="pr-3 py-3 flex items-center border-b border-gray-200 dark:border-gray-700"
            >
              <div class="flex-none flex items-center px-3">
                <h2 class="text-lg dark:text-gray-200 leading-4 font-bold">Pruners</h2>
              </div>

              <.live_component
                conf={@conf}
                id="search"
                module={SearchComponent}
                page={:pruners}
                params={without_defaults(@params, @default_params)}
                queryable={PrunerQuery}
                resolver={@resolver}
              />

              <div class="pl-3 ml-auto flex items-center">
                <SortComponent.select
                  id="pruners-sort"
                  by={~w(order name retention limit)}
                  page={:pruners}
                  params={sort_params(@params, @default_params)}
                />

                <.link
                  patch={can?(:insert_pruners, @access) && oban_path([:pruners, :new])}
                  id="new-pruner-button"
                  data-title="Create a new pruning rule"
                  phx-hook="Tippy"
                  aria-disabled={not can?(:insert_pruners, @access)}
                  class={[
                    "ml-3 h-10 flex items-center text-sm bg-white dark:bg-gray-800 px-3 py-2 border rounded-md",
                    can?(:insert_pruners, @access) &&
                      "text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-700 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 hover:text-blue-500 hover:border-blue-600 cursor-pointer",
                    not can?(:insert_pruners, @access) &&
                      "text-gray-400 dark:text-gray-500 border-gray-200 dark:border-gray-800 cursor-not-allowed opacity-50"
                  ]}
                >
                  <Icons.icon name="icon-plus-circle" class="mr-1 h-4 w-4" /> New
                </.link>
              </div>
            </div>

            <.warnings rules={@rules} status={@status} />

            <.live_component
              id="pruners-table"
              access={@access}
              chain={@rules}
              filtered?={filtered?(@params)}
              module={TableComponent}
              orderable?={orderable?(@params)}
              rules={@listed}
              status={@status}
            />
        <% end %>
      </div>

      <.live_component
        :if={@show_new_form}
        id="new-pruner-form"
        access={@access}
        conf={@conf}
        module={NewComponent}
      />
    </div>
    """
  end

  attr :rules, :list, required: true
  attr :status, :map, required: true

  defp warnings(assigns) do
    ~H"""
    <div
      :if={not @status.configured? or @status.sync_mode == :automatic or missing_default?(@rules)}
      class="divide-y divide-amber-200 dark:divide-amber-900/50"
    >
      <.warning :if={not @status.configured?} id="warning-unconfigured">
        No pruner is configured for this instance, so these rules are stored but never applied. Add
        <code class="font-mono">Oban.Pro.Pruner</code>
        to your Oban configuration to start pruning.
      </.warning>

      <.warning :if={@status.sync_mode == :automatic} id="warning-automatic">
        Sync mode is <code class="font-mono">:automatic</code>, so rules that aren't in your
        configuration are deleted when the pruner restarts. Rules added here won't survive a deploy
        unless you add them to your config as well.
      </.warning>

      <.warning :if={missing_default?(@rules)} id="warning-no-default">
        There's no <code class="font-mono">default</code>
        rule, so jobs that don't match any rule above are retained forever. The pruner creates one
        the next time it starts.
      </.warning>
    </div>
    """
  end

  attr :id, :string, required: true
  slot :inner_block, required: true

  defp warning(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex items-start px-3 py-3 bg-amber-50 dark:bg-amber-900/20 text-sm text-amber-800 dark:text-amber-300"
    >
      <Icons.icon name="icon-exclamation-circle" class="w-5 h-5 mr-2 shrink-0" />
      <p>{render_slot(@inner_block)}</p>
    </div>
    """
  end

  # With no rules at all the empty state already says so, and a missing default is not the
  # interesting part of that.
  defp missing_default?(rules), do: rules != [] and not Enum.any?(rules, &(&1.name == "default"))

  defp pro_promo(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-16 px-6">
      <div class="flex items-center justify-center w-16 h-16 rounded-full bg-violet-100 dark:bg-violet-900/30 mb-6">
        <Icons.icon name="icon-trash" class="w-8 h-8 text-violet-500 dark:text-violet-400" />
      </div>

      <h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3">
        Pruners
      </h2>

      <p class="text-center text-gray-600 dark:text-gray-400 max-w-3xl mb-6">
        Control exactly which completed, cancelled, and discarded jobs are retained, and for how
        long. Rules are matched in order, so a broad default can coexist with narrow exceptions for
        the queues and workers that need them.
      </p>

      <ul class="text-left text-gray-600 dark:text-gray-400 space-y-3 mb-8">
        <li class="flex items-start">
          <Icons.icon name="icon-check" class="w-5 h-5 text-violet-500 mr-2 mt-0.5 shrink-0" />
          <span>
            <span class="font-medium text-gray-700 dark:text-gray-300">Targeted Retention</span>
            — match on queue, worker, and state to retain by age or by count
          </span>
        </li>
        <li class="flex items-start">
          <Icons.icon name="icon-check" class="w-5 h-5 text-violet-500 mr-2 mt-0.5 shrink-0" />
          <span>
            <span class="font-medium text-gray-700 dark:text-gray-300">Archiving</span>
            — copy jobs into an archive table instead of discarding them entirely
          </span>
        </li>
        <li class="flex items-start">
          <Icons.icon name="icon-check" class="w-5 h-5 text-violet-500 mr-2 mt-0.5 shrink-0" />
          <span>
            <span class="font-medium text-gray-700 dark:text-gray-300">Persistent Rules</span>
            — stored in the database and editable at runtime, without a deploy
          </span>
        </li>
      </ul>

      <.link
        href="https://oban.pro"
        target="_blank"
        class="inline-flex items-center px-5 py-2.5 rounded-md bg-violet-600 hover:bg-violet-700 text-white font-medium transition-colors"
      >
        Learn about Oban Pro <Icons.icon name="icon-arrow-top-right-on-square" class="w-4 h-4 ml-2" />
      </.link>
    </div>
    """
  end

  attr :conf, :any, required: true

  defp migration_prompt(assigns) do
    postgres? = assigns.conf.repo.__adapter__() == Ecto.Adapters.Postgres

    assigns = assign(assigns, :postgres?, postgres?)

    ~H"""
    <div id="pruners-migration-prompt" class="flex flex-col items-center justify-center py-16 px-6">
      <div class="flex items-center justify-center w-16 h-16 rounded-full bg-gray-100 dark:bg-gray-800 mb-6">
        <Icons.icon name="icon-table-cells" class="w-8 h-8 text-gray-500 dark:text-gray-400" />
      </div>

      <%= if @postgres? do %>
        <h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3">
          Migration Required
        </h2>

        <p class="text-center text-gray-600 dark:text-gray-400 max-w-xl">
          There isn't an <code class="font-mono">oban_pruners</code>
          table in this database yet. Run the Oban Pro v1.8 migration to add it.
        </p>

        <div class="mt-4">
          <a
            href="https://oban.pro/docs/pro/Oban.Pro.Pruner.html"
            target="_blank"
            rel="noopener"
            class="text-base font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400 dark:hover:text-violet-300"
          >
            See migration instructions <span aria-hidden="true">&rarr;</span>
          </a>
        </div>
      <% else %>
        <h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3">
          PostgreSQL Required
        </h2>

        <p class="text-center text-gray-600 dark:text-gray-400 max-w-xl">
          Pruners require PostgreSQL and aren't available for this database.
        </p>
      <% end %>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = %{sort_by: "order", sort_dir: "asc"}

    socket
    |> assign(:has_pruners?, Utils.has_pruners?(socket.assigns.conf))
    |> assign(:pro_available?, Utils.has_pro?())
    |> assign(:default_params, default)
    |> assign_new(:configured_names, fn -> PrunerQuery.configured_names(socket.assigns.conf) end)
    |> assign_new(:detail, fn -> nil end)
    |> assign_new(:listed, fn -> [] end)
    |> assign_new(:params, fn -> default end)
    |> assign_new(:rule, fn -> nil end)
    |> assign_new(:rules, fn -> [] end)
    |> assign_new(:show_new_form, fn -> false end)
    |> assign_new(:status, fn -> PrunerQuery.service_status(socket.assigns.conf) end)
  end

  @impl Page
  def handle_refresh(socket) do
    %{conf: conf, detail: detail, has_pruners?: has_pruners?, params: params} = socket.assigns

    if has_pruners? do
      rules = PrunerQuery.all_rules(conf)
      rule = Enum.find(rules, &(&1.name == detail))

      socket =
        assign(socket,
          listed: PrunerQuery.display_rules(rules, params),
          rule: rule,
          rules: rules,
          status: PrunerQuery.service_status(conf)
        )

      # A rule deleted in another tab, or renamed out from under the URL, has nothing to show.
      if is_nil(rule) and not is_nil(detail) do
        push_patch(socket, to: index_path(socket), replace: true)
      else
        socket
      end
    else
      socket
    end
  end

  @impl Page
  def handle_params(%{"id" => "new"} = params, _uri, socket) do
    %{access: access, has_pruners?: has_pruners?, pro_available?: pro_available?} = socket.assigns

    if pro_available? and has_pruners? and can?(:insert_pruners, access) do
      socket =
        socket
        |> assign(detail: nil, page_title: page_title("New Rule"), show_new_form: true)
        |> assign_params(params)
        |> handle_refresh()

      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: oban_path(:pruners), replace: true)}
    end
  end

  def handle_params(%{"id" => name} = params, _uri, socket) do
    socket =
      socket
      |> assign(detail: name, page_title: page_title(name), show_new_form: false)
      |> assign_params(params)
      |> handle_refresh()

    {:noreply, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(detail: nil, page_title: page_title("Pruners"), show_new_form: false)
      |> assign_params(params)
      |> handle_refresh()

    {:noreply, socket}
  end

  defp assign_params(socket, params) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params(PrunerQuery)
      |> then(&Map.merge(socket.assigns.default_params, &1))

    assign(socket, params: params)
  end

  defp index_path(socket) do
    oban_path(:pruners, without_defaults(socket.assigns.params, socket.assigns.default_params))
  end

  # Sorting is applied on top of the filters, so both are kept in the sort menu's links.
  defp sort_params(params, default_params) do
    params
    |> without_defaults(default_params)
    |> Map.merge(Map.take(params, [:sort_by, :sort_dir]))
  end

  defp filtered?(params) do
    Enum.any?(PrunerQuery.filterable(), &Map.has_key?(params, &1))
  end

  # Moving a rule up or down only lines up with the evaluation chain while the table shows the
  # whole chain, in order.
  defp orderable?(params) do
    params.sort_by == "order" and params.sort_dir == "asc" and not filtered?(params)
  end

  @impl Page
  def handle_info({:pause_rule, rule}, socket) do
    enforce_access!(:pause_pruners, socket.assigns.access)

    result =
      Telemetry.action(:pause_pruner, socket, [name: rule.name], fn ->
        PrunerQuery.toggle_rule(socket.assigns.conf, rule, true)
      end)

    {:noreply, apply_result(socket, result, "Rule \"#{rule.name}\" paused")}
  end

  def handle_info({:resume_rule, rule}, socket) do
    enforce_access!(:pause_pruners, socket.assigns.access)

    result =
      Telemetry.action(:resume_pruner, socket, [name: rule.name], fn ->
        PrunerQuery.toggle_rule(socket.assigns.conf, rule, false)
      end)

    {:noreply, apply_result(socket, result, "Rule \"#{rule.name}\" resumed")}
  end

  def handle_info({:delete_rule, rule}, socket) do
    enforce_access!(:delete_pruners, socket.assigns.access)

    result =
      Telemetry.action(:delete_pruner, socket, [name: rule.name], fn ->
        PrunerQuery.delete_rule(socket.assigns.conf, rule)
      end)

    {:noreply, apply_result(socket, result, "Rule \"#{rule.name}\" deleted")}
  end

  def handle_info({:move_rule, name, offset}, socket) do
    enforce_access!(:update_pruners, socket.assigns.access)

    %{conf: conf, rules: rules} = socket.assigns

    case Enum.find_index(rules, &(&1.name == name)) do
      nil ->
        {:noreply, apply_result(socket, {:error, :not_found}, nil)}

      index ->
        result =
          Telemetry.action(:move_pruner, socket, [name: name], fn ->
            PrunerQuery.move_rule(conf, Enum.at(rules, index), index + offset)
          end)

        {:noreply, apply_result(socket, result, nil)}
    end
  end

  def handle_info({:insert_rule, opts}, socket) do
    enforce_access!(:insert_pruners, socket.assigns.access)

    result =
      Telemetry.action(:insert_pruner, socket, [name: opts[:name]], fn ->
        PrunerQuery.create_rule(socket.assigns.conf, opts)
      end)

    case result do
      {:ok, rule} ->
        message =
          if socket.assigns.status.configured? do
            "Rule \"#{rule.name}\" created"
          else
            "Rule \"#{rule.name}\" created — no pruner is running"
          end

        socket =
          socket
          |> put_flash_with_clear(:info, message)
          |> push_patch(to: oban_path(:pruners))

        {:noreply, socket}

      {:error, reason} ->
        send_update(NewComponent, id: "new-pruner-form", failure: reason)

        {:noreply, socket}
    end
  end

  def handle_info({:update_rule, name, lock_version, opts}, socket) do
    enforce_access!(:update_pruners, socket.assigns.access)

    result =
      Telemetry.action(:update_pruner, socket, [name: name], fn ->
        PrunerQuery.update_rule(socket.assigns.conf, name, lock_version, opts)
      end)

    case result do
      {:ok, _rule} ->
        socket =
          socket
          |> put_flash_with_clear(:info, "Rule \"#{name}\" updated")
          |> handle_refresh()

        send_update(DetailComponent, id: "detail", reseed: true)

        {:noreply, socket}

      {:error, reason} ->
        send_update(DetailComponent, id: "detail", failure: reason)

        {:noreply, handle_refresh(socket)}
    end
  end

  def handle_info(:refresh, socket) do
    {:noreply, handle_refresh(socket)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # A nil message means success is visible on its own, like a reordered row, so only failures
  # flash.
  defp apply_result(socket, result, message) do
    socket =
      case result do
        {:ok, _rule} when is_binary(message) ->
          put_flash_with_clear(socket, :info, message)

        {:ok, _rule} ->
          socket

        {:error, :not_found} ->
          put_flash_with_clear(socket, :warning, "Rule no longer exists")

        {:error, reason} when is_binary(reason) ->
          put_flash_with_clear(socket, :warning, reason)

        {:error, _changeset} ->
          put_flash_with_clear(
            socket,
            :warning,
            "Rule was changed elsewhere and has been reloaded"
          )
      end

    handle_refresh(socket)
  end
end
