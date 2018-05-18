defmodule ExoRedis.Command.Process.Info do
  use ExoRedis.Command.Process

  def process_command_args(_, _) do
    {:ok, version} = :application.get_key(:exo_redis, :vsn)

    [{:exo_redis_version, to_string(version)}] ++ Application.get_all_env(:exo_redis)
  end
end
