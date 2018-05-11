defmodule ExoRedis.Command.Process.Binary do
  @moduledoc """
   Handles all the operations for handling binary data (utf8 binaries)
  """

  use ExoRedis.Command.Process
  use Bitwise
  use Alias
  require Logger

  @wrong_type_error %Error{type: "Err", message: Error.err_msg(:wrong_type)}
  @ok "OK"

  def init(args) do
    {:ok, args}
  end

  ####### Retrieval Operations

  def process_command_args("GET", [key | _]) do
    case retrieve(key) do
      {:ok, data} ->
        data

      {:error, :key_type_error} ->
        @wrong_type_error

      {:error, :key_missing} ->
        :nodata
    end
  end

  def process_command_args("SET", [key, value]) do
    case store(key, value) do
      {:ok, _} -> @ok
      {:error, :flag_failed} -> :null_array
    end
  end

  def process_command_args("SET", [key, value | optional_flags]) do
    flags = process_optional_flags(optional_flags)

    case flags do
      %Error{} ->
        flags

      _ ->
        case store(key, value, flags) do
          {:ok, _} -> @ok
          {:error, :flag_failed} -> :null_array
        end
    end
  end

  defp process_optional_flags(["EX", seconds, "PX", mills, flag]) do
    try do
      set_flags =
        case flag do
          "NX" -> :set_if_exists
          "XX" -> :set_if_not_exists
          _ -> :set
        end

      Logger.debug(fn ->
        "process_optional_flags: EX: #{inspect(seconds)} PX: #{inspect(mills)}  flag: #{
          inspect(flag)
        } set_flags: #{set_flags}"
      end)

      %{
        expiry: [String.to_integer(seconds), String.to_integer(mills)],
        flag: set_flags
      }
    rescue
      e in ArgumentError ->
        Logger.debug(fn -> "Argument error: #{inspect(e)}" end)

        %Error{
          type: "Err",
          message: Error.err_msg(:wrong_syntax)
        }
    end
  end

  defp process_optional_flags(["EX", seconds, "PX", mills]) do
    process_optional_flags(["EX", seconds, "PX", mills, ""])
  end

  defp process_optional_flags(["EX", seconds, flag]) do
    process_optional_flags(["EX", seconds, "PX", "0", flag])
  end

  defp process_optional_flags(["EX", seconds]) do
    process_optional_flags(["EX", seconds, "PX", "0", ""])
  end

  defp process_optional_flags([flag]) when flag == "NX" or flag == "XX" do
    process_optional_flags(["EX", "-1", "PX", "0", flag])
  end

  defp process_optional_flags([_]) do
    process_optional_flags(["EX", "-1", "PX", "0", ""])
  end

  ####### Bit Operations
  def process_command_args("GETBIT", [key, position | _]) do
    Logger.debug(fn -> "GETBIT" <> key <> position end)

    try do
      position = String.to_integer(position)

      case retrieve(key) do
        {:ok, data} -> get_bit(data, position)
        {:error, :key_type_error} -> @wrong_type_error
        {:error, :key_missing} -> :nodata
      end
    rescue
      ArgumentError ->
        %Error{
          type: "Err",
          message: Error.err_msg(:out_of_range, "bit offset")
        }
    end
  end

  def process_command_args("GETBIT", [_]) do
    %Error{
      type: "Err",
      message: Error.err_msg(:wrong_args, "GETBIT")
    }
  end

  def process_command_args("SETBIT", [key, position, flag | _])
      when flag == "1" or flag == "0" do
    try do
      position = String.to_integer(position)

      case retrieve(key) do
        {:ok, data} ->
          {old_bit, new_data} = set_bit(data, position, flag)

          case store(key, new_data) do
            {:error, some_error} ->
              %Error{type: "Err", message: some_error}

            {:ok, _} ->
              old_bit
          end

        {:error, :key_type_error} ->
          @wrong_type_error

        {:error, :key_missing} ->
          # allocate 1 byte for new data so that we don't need resizing for every bit
          {old_bit, new_data} = set_bit(<<0::size(8)>>, position, flag)

          case store(key, new_data) do
            {:error, some_error} ->
              %Error{type: "Err", message: some_error}

            {:ok, _} ->
              old_bit
          end
      end
    rescue
      ArgumentError ->
        %Error{
          type: "Err",
          message: Error.err_msg(:out_of_range, "bit offset")
        }
    end
  end

  def process_command_args("SETBIT", [_]) do
    %Error{
      type: "Err",
      message: Error.err_msg(:wrong_args, "SETBIT")
    }
  end

  defp get_bit(string_data, position)
       when is_number(position) and is_binary(string_data) and position > 0 and
              position <= byte_size(string_data) * 8 do
    head_size = position - 1
    <<_::size(head_size), bit::1, _::bitstring>> = string_data
    bit
  end

  defp get_bit(_, _), do: 0

  # no resizing needed here
  defp set_bit(string_data, position, bit_flag)
       when (bit_flag == "1" or bit_flag == "0") and is_number(position) and
              is_binary(string_data) and position > 0 and
              position <= byte_size(string_data) * 8 do
    <<head::size(position), old_bit::1, tail::bitstring>> = string_data

    if bit_flag == "1" do
      {old_bit, <<head::size(position), 1::1, tail::bitstring>>}
    else
      {old_bit, <<head::size(position), 0::1, tail::bitstring>>}
    end
  end

  # resizing to fit the data, padding the original data with NUL bytes, i.e., <<0>>
  defp set_bit(string_data, position, bit_flag)
       when (bit_flag == "1" or bit_flag == "0") and is_number(position) and
              is_binary(string_data) and position > 0 and
              position > byte_size(string_data) * 8 do
    total_empty_bytes =
      (position - byte_size(string_data) * 8)
      |> next_power_of_2
      |> Kernel./(8)

    string_data
    |> append_empty_bytes(total_empty_bytes)
    |> set_bit(position, bit_flag)
  end

  # find the next (ceil) power of 2
  defp next_power_of_2(num, power \\ 2) do
    num = num >>> 1

    if num == 0 do
      power
    else
      next_power_of_2(
        num,
        power <<< 1
      )
    end
  end

  # append <<0>> bytes

  defp append_empty_bytes(original_data, total_bytes_to_append)
       when total_bytes_to_append > 0 do
    append_empty_bytes(
      original_data <> <<0::size(8)>>,
      total_bytes_to_append - 1
    )
  end

  defp append_empty_bytes(original_data, total_bytes_to_append)
       when total_bytes_to_append == 0 do
    original_data
  end
end
