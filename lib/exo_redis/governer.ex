defmodule ExoRedis.Governer.Supervisor do
  @moduledoc """
  the main supervisor governing all the other process in the application
  """
  use Supervisor
  @store_name :internal_store

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {ExoRedis.Command.ProcessSupervisor,
       strategy: :rest_for_one, restart: :permanent},
      Supervisor.Spec.worker(
        ExoRedis.ServerKickStarter,
        [],
        strategy: :one_for_one,
        restart: :permanent
      ),
      Supervisor.Spec.worker(
        ExoRedis.StorageProcess,
        [@store_name],
        strategy: :one_for_one,
        restart: :permanent
      ),
      Supervisor.Spec.worker(
        ExoRedis.StorageProcess.GC,
        [@store_name],
        strategy: :one_for_one,
        restart: :permanent
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
