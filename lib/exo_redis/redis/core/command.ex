defmodule ExoRedis.Command do
  require Record
  @type redis_command :: record(:redis_command, type: atom(), args: list())

  Record.defrecord(:redis_command, type: nil, args: [])
end

defmodule ExoRedis.Command.Handler do
  import ExoRedis.Command
  require Logger
  alias ExoRedis.RESP.BinaryPacker
  alias ExoRedis.RESP.ProtocolError
  alias ExoRedis.Command.Process
  alias ExoRedis.RESP.Parser
  alias ExoRedis.Server.Error
  alias ExoRedis.Util
  alias ExoRedis.Commands

  def process_command(raw_command) when is_binary(raw_command) do
    try do
      raw_command
      |> parse_command
      |> validate_command!()
      |> Process.process_command()
    rescue
      error -> error |> pack_error()
    end
  end

  defp parse_command(raw_command) do
    Logger.debug(fn -> "parsing  #{raw_command} " end)

    case Parser.parse(raw_command) do
      {:ok, command, _} when is_binary(command) ->
        Logger.debug(fn -> "Got Command  #{command} " end)
        {:ok, {Util.downcase_ascii(command), []}}

      {:ok, [command], _} ->
        Logger.debug(fn -> "Got Command  #{command} " end)
        {:ok, {Util.downcase_ascii(command), []}}

      {:ok, [command | args], _} ->
        Logger.debug(fn -> "Got Command+args  #{command} #{args}" end)

        {:ok, {Util.downcase_ascii(command), args}}

      {:continuation, _} ->
        {:error, %ProtocolError{message: "Unexpected EOD"}}

      {:error, %ProtocolError{} = protocol_error} ->
        Logger.debug(fn -> "Got protocol error #{inspect(protocol_error)}" end)
        {:error, protocol_error}
    end
  end

  defp validate_command!({:ok, {command_string, args}}) do
    case Commands.command_spec(command_string) do
      {:ok, {min_args, is_arg_required, process_module, command_atom}} ->
        args_length = length(args)

        if (is_arg_required && args_length >= min_args) ||
             (!is_arg_required && args_length == min_args) do
          {process_module, redis_command(type: command_atom, args: args)}
        else
          raise %Error{type: "Err", message: Error.err_msg(:wrong_args, command_string)}
        end

      {:error, :not_found} ->
        raise %Error{type: "Err", message: Error.err_msg(:wrong_command, command_string)}
    end
  end

  defp validate_command!({:error, some_error}) do
    raise some_error
  end

  defp pack_error(%ProtocolError{} = err) do
    BinaryPacker.pack(err)
  end

  defp pack_error(%Error{} = err) do
    BinaryPacker.pack(err)
  end

  defp pack_error(some_error) do
    Logger.error(fn -> "Unexpected error  #{inspect(some_error)}" end)

    %Error{type: "Err", message: "Unexpected error"} |> pack_error
  end
end
