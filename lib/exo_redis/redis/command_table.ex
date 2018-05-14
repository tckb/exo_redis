defmodule ExoRedis.Commands do
  @up_table %{
    # command, min_args,args_required, command process
    "get" => {1, true, ExoRedis.Command.Process.Binary},
    "set" => {2, true, ExoRedis.Command.Process.Binary},
    "getbit" => {1, true, ExoRedis.Command.Process.Binary},
    "setbit" => {1, true, ExoRedis.Command.Process.Binary},
    "zadd" => {3, true, ExoRedis.Command.Process.RBTree},
    "zrange" => {3, true, ExoRedis.Command.Process.RBTree},
    "zcard" => {3, true, ExoRedis.Command.Process.RBTree},
    "zcount" => {3, true, ExoRedis.Command.Process.RBTree},
    "info" => {0, false, ExoRedis.Command.Process.Info},
    "save" => {0, false, ExoRedis.Command.Process.SaveStorage}
  }
  def command_table do
    @up_table
  end

  def command_spec(command) when is_binary(command) do
    try do
      %{^command => spec} = @up_table
      {:ok, spec}
    rescue
      MatchError -> {:error, :not_found}
    end
  end
end
