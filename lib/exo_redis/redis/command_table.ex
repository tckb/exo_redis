defmodule ExoRedis.Commands do
  @up_table %{
    # command_string, min_args,args_required, command process, command
    "get" => {1, true, ExoRedis.Command.Process.Binary, :get},
    "set" => {2, true, ExoRedis.Command.Process.Binary, :set},
    "getbit" => {1, true, ExoRedis.Command.Process.Binary, :gbit},
    "setbit" => {1, true, ExoRedis.Command.Process.Binary, :sbit},
    "zadd" => {3, true, ExoRedis.Command.Process.RBTree, :zadd},
    "zrange" => {3, true, ExoRedis.Command.Process.RBTree, :zrng},
    "zcard" => {3, true, ExoRedis.Command.Process.RBTree, :zcrd},
    "zcount" => {3, true, ExoRedis.Command.Process.RBTree, :zcnt},
    "info" => {0, false, ExoRedis.Command.Process.Info, :inf},
    "save" => {0, false, ExoRedis.Command.Process.SaveStorage, :sve}
  }

  @type c_spec_t :: {pos_integer(), boolean(), module(), atom()}

  def command_table do
    @up_table
  end

  @doc """
  returns the command spec from the command table

  ## Examples
       iex> ExoRedis.Commands.command_spec("get")
       {:ok,{1, true, ExoRedis.Command.Process.Binary, :get}}
       iex> ExoRedis.Commands.command_spec("GET")
       {:error, :not_found}
  """
  @spec command_spec(String.t()) :: {:ok, c_spec_t} | {:error, :not_found}
  def command_spec(command) when is_binary(command) do
    %{^command => spec} = @up_table
    {:ok, spec}
  rescue
    MatchError -> {:error, :not_found}
  end
end
