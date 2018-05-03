defmodule ExoRedis.Command do
  @enforce_keys [:command]
  defstruct [:command, :args]
end

defmodule ExoRedis.Command.Handler do
  require Logger
  use Alias

  def handle_command(raw_command) do
    Logger.debug(fn -> "Handling  #{raw_command} " end)

    try do
      raw_command
      |> parse_command
      |> is_valid?
      |> CommandProcess.process_command()
    rescue
      error ->
        error
        |> parse_error()
    end
  end

  # this guys raises protocol errors
  defp parse_command(raw_command) do
    Logger.debug(fn -> "parsing  #{raw_command} " end)

    case ProtocolParser.parse(raw_command) do
      {:ok, command, _} when is_binary(command) ->
        Logger.debug(fn -> "Got Command  #{command} " end)
        {:ok, %Command{command: command, args: []}}

      {:ok, [command], _} ->
        Logger.debug(fn -> "Got Command  #{command} " end)
        {:ok, %Command{command: command, args: []}}

      {:ok, [command | args], _} ->
        Logger.debug(fn -> "Got Command+args  #{command} #{args}" end)
        {:ok, %Command{command: command, args: args}}

      {:continuation, _} ->
        {:error, %ProtocolError{message: "Unexpected EOD"}}

      {:error, %ProtocolError{} = protocol_error} ->
        Logger.debug(fn -> "Got protocol error #{inspect(protocol_error)}" end)
        {:error, protocol_error}
    end
  end

  defp is_valid?({:ok, %Command{command: command, args: args} = cmd}) do
    Logger.debug(fn -> "validating  #{inspect(cmd)} " end)

    case CommandSpec.get_spec(command) do
      {:ok, command_spec} ->
        args_length = length(args)
        specs_length = command_spec.min_required_args()

        # we are going a bit strict on the argument check here, redis is a bit linient on this
        if (command_spec.args_required && args_length >= specs_length) ||
             (!command_spec.args_required && args_length == specs_length) do
          case command_spec.process_mod
               |> CommandProcess.spawn_command_process(cmd) do
            {:ok, cmd_process} ->
              Logger.debug(fn -> "is_valid: #{inspect(cmd_process)}" end)

              cmd_process

            {:error, _} ->
              Logger.debug(fn ->
                "No CommandHandler exists for #{command}"
              end)

              raise %Error{
                type: "Err",
                message: Error.err_msg(:wrong_command, command)
              }
          end
        else
          raise %Error{
            type: "Err",
            message: Error.err_msg(:wrong_args, command)
          }
        end

      {:error, %Error{} = spec_error} ->
        raise spec_error
    end
  end

  defp is_valid?({error, some_error}) do
    raise some_error
  end

  defp parse_error(%ProtocolError{} = err) do
    err
    |> ProtocolPacker.pack()
  end

  defp parse_error(%Error{} = err) do
    err
    |> ProtocolPacker.pack()
  end

  defp parse_error(some_error) do
    Logger.error(fn -> "Unexpected error  #{inspect(some_error)}" end)

    %Error{
      type: "Err",
      message: "Unexpected error"
    }
    |> parse_error
  end
end
