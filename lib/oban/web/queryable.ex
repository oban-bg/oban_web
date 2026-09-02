defmodule Oban.Web.Queryable do
  @moduledoc false

  # Shared searching, filtering, and sorting for page query modules.
  #
  # Using this module implements the full search toolbar contract from a single qualifiers/0
  # callback. See Oban.Web.Search for the qualifier format.
  #
  # Modules that filter and sort rows in memory implement the filter/2, order/2, and optionally
  # sorter/2 callbacks, then pipe rows through refine/4.

  alias Oban.Web.Search

  @doc """
  Qualifier declarations that drive parsing, suggestions, and filtering.
  """
  @callback qualifiers() :: keyword()

  @doc """
  Whether a row matches a single filtering condition, as `{qualifier, values}`.
  """
  @callback filter(row :: term(), condition :: {atom(), term()}) :: boolean()

  @doc """
  The value used to sort a row for the given field.
  """
  @callback order(row :: term(), sort_by :: atom()) :: term()

  @doc """
  The sorter passed to `Enum.sort_by/3`, defaulting to the direction alone.
  """
  @callback sorter(sort_by :: atom(), dir :: :asc | :desc) :: term()

  @optional_callbacks filter: 2, order: 2, sorter: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Oban.Web.Queryable

      alias Oban.Web.{Queryable, Search}

      def append(terms, choice), do: Search.append(terms, choice, qualifiers())

      def complete(terms, conf), do: Search.complete(terms, qualifiers(), conf)

      def filterable, do: Search.filterable(qualifiers())

      def known_params, do: Search.known_params(qualifiers())

      def parse(terms), do: Search.parse(terms, qualifiers())

      def suggest(terms, conf, opts \\ []), do: Search.suggest(terms, qualifiers(), conf, opts)

      @impl Queryable
      def sorter(_sort_by, dir), do: dir

      defoverridable sorter: 2
    end
  end

  @doc """
  Filter, sort, and limit rows in memory using a module's declared callbacks.

  The limit is taken from the params, falling back to the `:limit` option, and left unlimited
  when neither is present.
  """
  def refine(rows, module, params, opts) do
    {sort_by, sort_dir} = parse_sort(params, Keyword.fetch!(opts, :default_sort))
    conditions = Map.take(params, module.filterable())

    rows
    |> Enum.filter(&filter(module, &1, conditions))
    |> Enum.sort_by(&module.order(&1, sort_by), module.sorter(sort_by, sort_dir))
    |> limit(Map.get(params, :limit, opts[:limit]))
  end

  defp filter(_module, _row, conditions) when map_size(conditions) == 0, do: true

  defp filter(module, row, conditions) do
    Enum.all?(conditions, &module.filter(row, &1))
  end

  defp limit(rows, count) when is_integer(count), do: Enum.take(rows, count)
  defp limit(rows, _count), do: rows

  defp parse_sort(%{sort_by: sort_by, sort_dir: sort_dir}, _default) do
    {String.to_existing_atom(sort_by), String.to_existing_atom(sort_dir)}
  end

  defp parse_sort(_params, default), do: default
end
