defmodule ExoRedis.Command do
  @enforce_keys [:command]
  defstruct [:command, :args]
end

defmodule ExoRedis.Command.Handler do
  require Logger
  use Alias

  def process_command(raw_command) when is_binary(raw_command) do
    try do
      raw_command
      |> parse_command
      |> validate_command!()
      |> CommandProcess.process_command()
    rescue
      error -> error |> pack_error()
    end
  end

  defp parse_command(raw_command) do
    Logger.debug(fn -> "parsing  #{raw_command} " end)

    case ProtocolParser.parse(raw_command) do
      {:ok, command, _} when is_binary(command) ->
        Logger.debug(fn -> "Got Command  #{command} " end)
        {:ok, %Command{command: command |> ExoRedis.Util.downcase(), args: []}}

      {:ok, [command], _} ->
        Logger.debug(fn -> "Got Command  #{command} " end)
        {:ok, %Command{command: command |> ExoRedis.Util.downcase(), args: []}}

      {:ok, [command | args], _} ->
        Logger.debug(fn -> "Got Command+args  #{command} #{args}" end)

        {:ok,
         %Command{command: command |> ExoRedis.Util.downcase(), args: args}}

      {:continuation, _} ->
        {:error, %ProtocolError{message: "Unexpected EOD"}}

      {:error, %ProtocolError{} = protocol_error} ->
        Logger.debug(fn -> "Got protocol error #{inspect(protocol_error)}" end)
        {:error, protocol_error}
    end
  end

  defp validate_command!({:ok, %Command{command: command, args: args} = cmd}) do
    case CommandList.command_spec(command) do
      {:ok, {min_args, is_arg_required, process_module}} ->
        args_length = length(args)

        if (is_arg_required && args_length >= min_args) ||
             (!is_arg_required && args_length == min_args) do
          # this is what we expect
          {process_module, cmd}
        else
          raise %Error{
            type: "Err",
            message: Error.err_msg(:wrong_args, command)
          }
        end

      {:error, _} ->
        raise %Error{
          type: "Err",
          message: Error.err_msg(:wrong_command, command)
        }
    end
  end

  defp validate_command!({:error, some_error}) do
    raise some_error
  end

  defp pack_error(%ProtocolError{} = err) do
    err
    |> ProtocolPacker.pack()
  end

  defp pack_error(%Error{} = err) do
    err
    |> ProtocolPacker.pack()
  end

  defp pack_error(some_error) do
    Logger.error(fn -> "Unexpected error  #{inspect(some_error)}" end)

    %Error{
      type: "Err",
      message: "Unexpected error"
    }
    |> pack_error
  end
end
