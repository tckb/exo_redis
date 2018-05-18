defmodule ExoRedis.Command.ProcessSupervisor do
  @moduledoc """
  the supervisor responsible for all command process
  """
  use Supervisor
  require Logger

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
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
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
