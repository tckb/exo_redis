defmodule Alias do
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
    end
  end
end
