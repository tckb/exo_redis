defmodule ExoRedis.Governer.Supervisor do
  use Supervisor
  @store_name :internal_store

  def start_link(args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(args) do
    datastore = MerklePatriciaTree.DB.ETS.init(@store_name)

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
        [datastore],
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
