defmodule Alias do
  @moduledoc """
   common alias across the app
  """
  defmacro __using__(_) do
    quote do
      alias ExoRedis.Server.Error, as: Error
      alias ExoRedis.Command, as: Command
      alias ExoRedis.Command.Spec, as: CommandSpec
      alias ExoRedis.Command.Process, as: CommandProcess
      alias ExoRedis.RESP.BinaryPacker, as: ProtocolPacker
      alias ExoRedis.RESP.ProtocolError, as: ProtocolError
      alias ExoRedis.RESP.Parser, as: ProtocolParser
      alias ExoRedis.StorageProcess, as: InternalStorage
      alias ExoRedis.Commands, as: CommandList
      alias ExoRedis.Util
      import ExoRedis.Command
    end
  end
end
