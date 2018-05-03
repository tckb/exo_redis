defmodule ExoRedis.Command.ProcessSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: []
    )
  end

  def register_command_processor(worker_mod) do
    child_pid =
      case DynamicSupervisor.start_child(
             __MODULE__,
             Supervisor.Spec.worker(worker_mod, [])
           ) do
        {:ok, pid} ->
          pid

        # this could happen if another contending process gave 'register_command_processor'
        {:error, {:already_started, pid}} ->
          pid
      end

    Logger.debug(fn -> "#{__MODULE__} child #{worker_mod}" end)
    {:ok, child_pid}
  end
end
