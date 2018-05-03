defmodule ExoRedis.Command.Process.RBTree do
  use ExoRedis.Command.Process
  require Logger
  @wrong_type_error %Error{type: "Err", message: Error.err_msg(:wrong_type)}

  def init(args) do
    {:ok, args}
  end

  @doc """
    add only one member, with no flag considered
    this might not guarentee O(log(n))
  """
  def process_command_args("ZADD", [key, score, memeber | _]) do
    score = String.to_integer(score)

    case retrieve(key) do
      {:ok, key_sset} ->
        Logger.debug(fn -> "key: #{key} key_sset: #{inspect(key_sset)}" end)

        # there's a bug in the ds;
        return =
          try do
            key_sset
            |> ZSet.zrank(memeber)
            |> Kernel.>=(0)
          rescue
            FunctionClauseError ->
              # non-existant member
              true
          end

        case store(
               key,
               key_sset
               |> ZSet.zadd(score, memeber),
               %{
                 expiry: [-1, 0],
                 flag: :set
               }
             ) do
          {:error, :key_type_error} -> @wrong_type_error
          {:error, :flag_failed} -> :null_array
          {:ok, _} -> return
        end

      {:error, :key_type_error} ->
        @wrong_type_error

      {:error, :key_missing} ->
        case store(
               key,
               ZSet.new()
               |> ZSet.zadd(score, memeber),
               %{
                 expiry: [-1, 0],
                 flag: :set
               }
             ) do
          {:error, :key_type_error} ->
            @wrong_type_error

          {:error, :flag_failed} ->
            :null_array

          # since we are only adding one member for a new key
          {:ok, _} ->
            true
        end
    end
  end

  def process_command_args("ZCOUNT", [key, min, max | _]) do
    min = String.to_integer(min)
    max = String.to_integer(max)

    case retrieve(key) do
      {:ok, key_sset} ->
        key_sset
        |> ZSet.zcount(min, max)

      {:error, :key_type_error} ->
        @wrong_type_error

      {:error, :key_missing} ->
        :nodata
    end
  end

  def process_command_args("ZCARD", [key | rest]) do
    case retrieve(key) do
      {:ok, key_sset} ->
        key_sset
        |> ZSet.zcard()

      {:error, :key_type_error} ->
        @wrong_type_error

      {:error, :key_missing} ->
        0
    end
  end

  def process_command_args("ZRANGE", [key, start, stop | _]) do
    start = String.to_integer(start)
    stop = String.to_integer(stop)

    case retrieve(key) do
      {:ok, key_sset} ->
        key_sset
        |> ZSet.zrange(start, stop)

      {:error, :key_type_error} ->
        @wrong_type_error

      {:error, :key_missing} ->
        :nodata
    end
  end
end
