defmodule ExoRedis.Server.Error do
  defexception [:type, :message]
  @type t :: %__MODULE__{type: binary(), message: binary()}

  @wrong_type "WRONGTYPE Operation against a key holding the wrong kind of value"
  @wrong_args "wrong number of arguments for '"
  @wrong_command "unknown command '"
  @out_of_range " is not an integer or out of range"
  @empty_prefix "'"
  @command_suffix "' command"
  @wrong_syntax "syntax error"

  def err_msg(type, wrong_command \\ "") do
    case type do
      :wrong_type -> @wrong_type
      :wrong_args -> [@wrong_args, wrong_command, @command_suffix]
      :out_of_range -> [wrong_command, @out_of_range]
      :wrong_command -> [@wrong_command, wrong_command, @empty_prefix]
      :wrong_syntax -> @wrong_syntax
    end
  end
end
