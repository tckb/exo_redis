defmodule ExoRedis.Command.ProcessSupervisor do
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      Supervisor.Spec.worker(
        ExoRedis.Command.Process.Binary,
        [],
        strategy: :one_for_one,
        restart: :permanent
      ),
      Supervisor.Spec.worker(
        ExoRedis.Command.Process.RBTree,
        [],
        strategy: :one_for_one,
        restart: :permanent
      ),
      Supervisor.Spec.worker(
        ExoRedis.Command.Process.Info,
        [],
        strategy: :one_for_one,
        restart: :permanent
      ),
      Supervisor.Spec.worker(
        ExoRedis.Command.Process.SaveStorage,
        [],
        strategy: :one_for_one,
        restart: :permanent
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
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
