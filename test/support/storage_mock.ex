if Code.ensure_loaded?(Oban.Pro.Storage) do
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

    def store(key, payload) do
      :ets.insert(@table, {key, payload})

      key
    end

    @impl Oban.Pro.Storage
    def init(opts), do: Map.new(opts)

    @impl Oban.Pro.Storage
    def put(key, payload, _conf) do
      store(key, payload)

      :ok
    end

    @impl Oban.Pro.Storage
    def fetch_all(keys, conf) do
      if sleep = conf[:sleep], do: Process.sleep(sleep)

      case conf do
        %{error: reason} -> {:error, reason}
        %{raise: message} -> raise message
        _conf -> {:ok, take(keys)}
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
