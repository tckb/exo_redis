defmodule ExoRedis.StorageProcess.GC do
  @moduledoc """
   the garbage collector responsible for dumping all the keys that are expired
  """
  use GenServer
  require Logger

  @status_mark_for_eviction :to_be_evicted
  # generally sweep interval should be long enough
  @sweep_interval Application.get_env(:exo_redis, :gc_mark_cycle)
  # this full sweep will do a full table scan for marking items to expire
  @full_scan_marker_interval Application.get_env(:exo_redis, :gc_sweep_cycle)
  # the selector used for fetching the keys that are about to be evicted
  @expired_keys_selector [
    {
      {:"$1", %{status: :to_be_evicted, ttl: :_, value: :_}},
      [],
      [:"$1"]
    }
  ]
  # the selector for fetching only live entries
  @live_key_selector [
    {
      {:"$1", %{status: :"$2", ttl: :"$4", value: :"$3"}},
      [{:>, :"$4", 0}],
      [{{:"$1", :"$3", :"$4"}}]
    }
  ]

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(ets_table) do
    sweep_expired_keys()
    {:ok, ets_table}
  end

  def handle_info(:sweep, ets_table) do
    # fire off next sweep
    do_sweep(ets_table)
    sweep_expired_keys()
    {:noreply, ets_table}
  end

  def handle_info(:full_scan, ets_table) do
    # fire off next sweep
    spawn(&sweep_expired_keys/0)
    do_fullscan_mark(ets_table)
    {:noreply, ets_table}
  end

  defp do_sweep(ets_table, keys_to_sweep \\ nil) do
    case keys_to_sweep do
      nil ->
        Logger.debug(fn ->
          "sweep started @ #{:os.system_time(:milli_seconds)}"
        end)

        do_sweep(ets_table, :ets.select(ets_table, @expired_keys_selector))

      [key_to_sweep | rest] ->
        Logger.debug(fn -> "sweeping off #{key_to_sweep}" end)

        :ets.delete(ets_table, key_to_sweep)
        do_sweep(ets_table, rest)

      [] ->
        Logger.debug(fn ->
          "sweep completed @ #{:os.system_time(:milli_seconds)}"
        end)
    end
  end

  defp do_fullscan_mark(ets_table, key_with_epoch \\ nil) do
    case key_with_epoch do
      nil ->
        Logger.debug(fn ->
          "marking started @ #{:os.system_time(:milli_seconds)}"
        end)

        do_fullscan_mark(ets_table, :ets.select(ets_table, @live_key_selector))

      [{key_to_mark, value, ttl_epoch} | rest] ->
        if ttl_epoch <= :os.system_time(:milli_seconds) do
          :ets.insert(ets_table, {
            key_to_mark,
            %{
              value: value,
              status: @status_mark_for_eviction,
              ttl: 0
            }
          })

          Logger.debug(fn -> "marking off #{key_to_mark}" end)
        end

        do_fullscan_mark(ets_table, rest)

      [] ->
        Logger.debug(fn ->
          "mark completed @ #{:os.system_time(:milli_seconds)}"
        end)
    end
  end

  defp sweep_expired_keys() do
    Process.send_after(self(), :sweep, @sweep_interval)
    Process.send_after(self(), :full_scan, @full_scan_marker_interval)
  end

  def marked_keys_selector() do
    :ets.fun2ms(fn {key, %{status: :to_be_evicted, value: _, ttl: _}} ->
      key
    end)
  end
end
