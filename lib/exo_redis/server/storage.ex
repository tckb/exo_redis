defmodule ExoRedis.StorageProcess do
  @moduledoc """
   the storage process responsible for handling storing & retrieving data out of the internal storage.
   the internal logistics of handling the actual data is opeque to the caller
  """

  @type ttl_type :: {-1 | pos_integer(), non_neg_integer()}
  @type store_mode_type :: :sync | :async

  use GenServer
  require Logger
  @status_mark_for_eviction :to_be_evicted
  @status_alive :active
  @status_alive_perpetuity :active_until_dead

  ########
  ## Client Apis
  #######

  @doc """
   retrieves the data from internal storage, technically the key, and value can be an elixir terms

   ## Examples
        iex> ExoRedis.StorageProcess.put_data(:key1, "value1")
        :ok
        iex> ExoRedis.StorageProcess.get_data(:key1)
        {:ok,"value1"}
        iex> ExoRedis.StorageProcess.get_data(:key2)
        {:error, :not_found}
        iex> ExoRedis.StorageProcess.put_data({:key1,:key2}, [1,2,3,4,5])
        :ok
        iex> ExoRedis.StorageProcess.get_data({:key1,:key2})
        {:ok,[1,2,3,4,5]}
        iex> ExoRedis.StorageProcess.put_data(:self_pid, self())
        :ok
        iex> ExoRedis.StorageProcess.get_data(:self_pid)
        {:ok, self()}

  """
  @spec get_data(any()) :: {:error, :not_found} | {:ok, any()}
  def get_data(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
    stores the data into the storage with optionally associating time-to-live associated with it.
  """
  @spec put_data(any(), any(), ttl_type, store_mode_type) :: :ok | {:error, :badvalue}
  def put_data(key, value, ttl \\ {-1, 0}, mode \\ :sync) do
    case mode do
      :async ->
        GenServer.cast(__MODULE__, {:put, key, value, ttl})
        :ok

      _ ->
        GenServer.call(__MODULE__, {:put, key, value, ttl})
    end
  end

  @doc """
   purges the data from the storage
  """
  @spec purge_data(any()) :: {:ok, true} | {:error, :not_found}
  def purge_data(key) do
    GenServer.call(__MODULE__, {:remove, key})
  end

  @doc """
  checks if the key is present in the storage
  """
  @spec is_key_present?(any()) :: {:ok, boolean()}
  def is_key_present?(key) do
    GenServer.call(__MODULE__, {:check_member, key})
  end

  ########
  ## Internal Methods
  #######

  def start_link(arg \\ :internal_store) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(ets_table_name) do
    # use ETS backed datastore, its easier for lookups
    :ets.new(ets_table_name, [
      :set,
      :named_table,
      :public
    ])

    {:ok, ets_table_name}
  end

  def handle_call({:get, key}, _from, ets_table_name) do
    keyval = ets_get(ets_table_name, key)

    case keyval do
      :not_found ->
        {:reply, {:error, :not_found}, ets_table_name}

      {:ok, data} ->
        #  oh oh , evict the key
        case data do
          %{value: value, status: @status_alive, ttl: ttl_epoch} ->
            if ttl_epoch <= :os.system_time(:milli_seconds) do
              Logger.debug(fn -> "marking #{key} for eviction" end)

              # mark for eviction
              ets_put!(ets_table_name, key, %{
                value: data.value,
                status: @status_mark_for_eviction,
                ttl: 0
              })

              {
                :reply,
                {:error, :not_found},
                ets_table_name
              }
            else
              {:reply, {:ok, value}, ets_table_name}
            end

          %{value: value, status: @status_alive_perpetuity, ttl: _} ->
            {:reply, {:ok, value}, ets_table_name}

          %{value: _, status: @status_mark_for_eviction, ttl: _} ->
            {:reply, {:error, :not_found}, ets_table_name}
        end
    end
  end

  def handle_call(
        {:put, key, value, {ttl_seconds, ttl_milli_seconds} = ttl},
        _from,
        ets_table_name
      )
      when ttl_seconds >= 0 and ttl_milli_seconds >= 0 do
    ets_put!(ets_table_name, key, %{
      value: value,
      status: @status_alive,
      ttl: ttl_epoch(ttl)
    })

    {:reply, :ok, ets_table_name}
  end

  def handle_call({:put, key, value, {_, _}}, _from, ets_table_name) do
    ets_put!(ets_table_name, key, %{
      value: value,
      status: @status_alive_perpetuity,
      ttl: :infinity
    })

    {:reply, :ok, ets_table_name}
  end

  def handle_call({:put, _, _, _}, _from, ets_table_name) do
    {:reply, {:error, :badvalue}, ets_table_name}
  end

  def handle_call({:check_member, key}, _from, ets_table_name) do
    {:reply, {:ok, :ets.member(:internal_store, key)}, ets_table_name}
  end

  def handle_call({:remove, key}, _from, ets_table_name) do
    if :ets.member(:internal_store, key) do
      :ets.delete(ets_table_name, key)
      {:reply, {:ok, true}, ets_table_name}
    else
      {:reply, {:error, :not_found}, ets_table_name}
    end
  end

  def handle_cast(
        {:put, key, value, ttl},
        ets_table_name
      ) do
    handle_call({:put, key, value, ttl}, self(), ets_table_name)
    {:noreply, ets_table_name}
  end

  def ttl_epoch({ttl_seconds, ttl_milli_seconds}),
    do: :os.system_time(:milli_seconds) + ttl_seconds * 1000 + ttl_milli_seconds

  defp ets_get(db_ref, key) do
    case :ets.lookup(db_ref, key) do
      [{^key, v} | _rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  defp ets_put!(db_ref, key, value) do
    case :ets.insert(db_ref, {key, value}) do
      true -> :ok
    end
  end
end
