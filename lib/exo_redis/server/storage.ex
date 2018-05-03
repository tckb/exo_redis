defmodule ExoRedis.StorageProcess do
  alias MerklePatriciaTree.DB, as: DB
  alias ExoRedis.StorageProcess.GC, as: StorageGC

  use GenServer
  require Logger
  @status_mark_for_eviction :to_be_evicted
  @status_alive :active
  @status_alive_perpetuity :active_until_dead

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def get_data(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def put_data(key, value, ttl \\ [-1, 0]) do
    GenServer.call(__MODULE__, {:put, key, value, ttl})
  end

  def purge_data(key) do
    GenServer.call(__MODULE__, {:remove, key})
  end

  def is_key_present?(key) do
    GenServer.call(__MODULE__, {:check_member, key})
  end

  ########

  def init(datastore) do
    # use ETS backed datastore, its easier for lookups
    :ets.new(:metadata, [:set, :named_table, :public])
    {:ok, datastore}
  end

  @doc """
   for now, we follow a lazy cache cleaning
  """
  def handle_call({:get, key}, _from, datastore) do
    keyval = DB.get(datastore, key)

    case keyval do
      :not_found ->
        {:reply, {:error, :not_found}, datastore}

      {:ok, data} ->
        #  oh oh , evict the key
        case data do
          %{value: value, status: @status_alive, ttl: ttl_epoch} ->
            if ttl_epoch <= :os.system_time(:milli_seconds) do
              Logger.debug(fn -> "marking #{key} for eviction" end)

              # no ttl, this is already expired
              status =
                DB.put!(datastore, key, %{
                  value: data.value,
                  status: @status_mark_for_eviction,
                  ttl: 0
                })

              case status do
                # say this is not found
                :ok ->
                  {
                    :reply,
                    {:error, :not_found},
                    datastore
                  }

                _ ->
                  Logger.error(
                    "Unable to update eviction status for key #{key}, status: #{
                      status
                    }"
                  )

                  {:reply, {:error, :not_found}, datastore}
              end
            else
              {:reply, {:ok, value}, datastore}
            end

          %{value: value, status: @status_alive_perpetuity, ttl: _} ->
            {:reply, {:ok, value}, datastore}

          %{value: value, status: @status_mark_for_eviction, ttl: _} ->
            {:reply, {:error, :not_found}, datastore}
        end
    end
  end

  def handle_call(
        {:put, key, value, [ttl_seconds, ttl_milli_seconds] = ttl},
        _from,
        datastore
      )
      when ttl_seconds > 0 and ttl_milli_seconds >= 0 do
    status =
      DB.put!(datastore, key, %{
        value: value,
        status: @status_alive,
        ttl: ttl_epoch(ttl)
      })

    case status do
      :ok -> {:reply, :ok, datastore}
      _ -> {:reply, {:error, status}, datastore}
    end
  end

  def handle_call({:put, key, value, [-1, 0]}, _from, datastore) do
    status =
      DB.put!(datastore, key, %{
        value: value,
        status: @status_alive_perpetuity,
        ttl: :infinity
      })

    case status do
      :ok -> {:reply, :ok, datastore}
      _ -> {:reply, {:error, status}, datastore}
    end
  end

  def handle_call({:put, _, _, _}, _from, datastore) do
    {:reply, {:error, "bad value"}, datastore}
  end

  def handle_call({:check_member, key}, _from, datastore) do
    {:reply, {:ok, :ets.member(:internal_store, key)}, datastore}
  end

  def handle_call({:remove, key}, _from, datastore) do
    data = DB.get(datastore, key)

    case data do
      :not_found ->
        {:reply, {:error, :not_found}, datastore}

      {:ok, value} ->
        status = :ets.delete(datastore, key)

        case status do
          true -> {:reply, {:ok, status}, datastore}
          _ -> {:reply, {:error, status}, datastore}
        end
    end
  end

  def ttl_epoch([ttl_seconds, ttl_milli_seconds]),
    do: :os.system_time(:milli_seconds) + ttl_seconds * 1000 + ttl_milli_seconds
end
