if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.StorageMock do
    @moduledoc false

    @behaviour Oban.Pro.Storage

    @table :oban_web_storage_mock

    def setup do
      if :ets.whereis(@table) == :undefined do
        :ets.new(@table, [:public, :named_table])
      end

      :ok
    end

    def break(reason), do: :ets.insert(@table, {:error, reason})

    def reset, do: :ets.delete_all_objects(@table)

    @impl Oban.Pro.Storage
    def init(opts), do: Map.new(opts)

    @impl Oban.Pro.Storage
    def put(key, payload, _conf) do
      :ets.insert(@table, {key, payload})

      :ok
    end

    @impl Oban.Pro.Storage
    def fetch_all(keys, _conf) do
      case :ets.lookup(@table, :error) do
        [{:error, reason}] -> {:error, reason}
        [] -> {:ok, take(keys)}
      end
    end

    @impl Oban.Pro.Storage
    def delete_all(keys, _conf) do
      Enum.each(keys, &:ets.delete(@table, &1))

      :ok
    end

    defp take(keys) do
      for key <- keys, [{^key, payload}] <- [:ets.lookup(@table, key)], into: %{} do
        {key, payload}
      end
    end
  end
end
