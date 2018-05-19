defmodule ExoRedis.RESP do
  defmodule ProtocolError do
    defexception [:message]
  end

  defmodule BinaryPacker do
    # data type prefixes
    @binary_prefix ?+
    @int_prefix ?:
    @bulk_string_prfix ?$
    @array_prefix ?*
    @error_prefix ?-

    # constants
    @crlf "\r\n"
    # null bulk string
    @nodata_reply [@bulk_string_prfix, "-1", @crlf]
    # null array reply - this is legacy format
    @null_array_reply [@array_prefix, "-1", @crlf]

    def nodata_reply, do: @nodata_reply
    def null_array_reply, do: @null_array_reply

    def pack(simple_boolean) when is_boolean(simple_boolean) do
      if simple_boolean do
        pack(1)
      else
        pack(0)
      end
    end

    def pack(simple_string) when is_binary(simple_string) do
      [@binary_prefix, simple_string, @crlf]
    end

    def pack(integer_data) when is_integer(integer_data) do
      [@int_prefix, Integer.to_string(integer_data), @crlf]
    end

    def pack(arrays) when is_list(arrays) do
      {packed, size} =
        Enum.map_reduce(arrays, 0, fn item, acc ->
          string =
            if is_tuple(item) do
              item
              |> Tuple.to_list()
              |> Enum.map(fn x -> to_string(x) end)
              |> Enum.reverse()
              |> Enum.reduce(fn x, acc -> x <> ": " <> acc end)
            else
              to_string(item)
            end

          packed_item = [
            @bulk_string_prfix,
            Integer.to_string(byte_size(string)),
            @crlf,
            string,
            @crlf
          ]

          {packed_item, acc + 1}
        end)

      [@array_prefix, Integer.to_string(size), @crlf, packed]
    end

    def pack(%ExoRedis.Server.Error{} = err) do
      pack_err(err.type, err.message)
    end

    def pack(%ExoRedis.RESP.ProtocolError{} = err) do
      pack_err("ERR", ["ProtocolError: ", err.message])
    end

    def pack(_) do
      raise ExoRedis.RESP.ProtocolError, message: "invalid data to pack"
    end

    # for iolists
    defp pack_err(error_type, msg) do
      [@error_prefix, [error_type, " ", msg, @crlf]]
    end
  end

  defmodule Parser do
    @crlf "\r\n"

    def parse("+" <> rest), do: parse_simple_string(rest)
    def parse("-" <> rest), do: parse_error(rest)
    def parse(":" <> rest), do: parse_integer(rest)
    def parse("$" <> rest), do: parse_bulk_string(rest)
    def parse("*" <> rest), do: parse_array(rest)
    def parse(""), do: {:continuation, &parse/1}

    def parse(rest) do
      {:error,
       %ExoRedis.RESP.ProtocolError{
         message: ExoRedis.Server.Error.err_msg(:wrong_command, rest)
       }}
    end

    # Type parsers

    defp parse_simple_string(data) do
      until_crlf(data)
    end

    defp parse_error(data) do
      data
      |> until_crlf()
      |> split_error_message()
      |> resolve_cont(
        &{%ExoRedis.Server.Error{type: &1 |> hd, message: &1 |> tl |> hd}, &2}
      )
    end

    defp split_error_message({:ok, full_error, rest}) do
      {:ok, String.split(full_error, " ", parts: 2), rest}
    end

    defp parse_integer(""), do: {:continuation, &parse_integer/1}

    defp parse_integer("-" <> rest),
      do: resolve_cont(parse_integer_without_sign(rest), &{:ok, -&1, &2})

    defp parse_integer(bin), do: parse_integer_without_sign(bin)

    defp parse_integer_without_sign("") do
      {:continuation, &parse_integer_without_sign/1}
    end

    defp parse_integer_without_sign(<<digit, _::binary>> = bin)
         when digit in ?0..?9 do
      resolve_cont(parse_integer_digits(bin, 0), fn i, rest ->
        resolve_cont(until_crlf(rest), fn
          "", rest ->
            {:ok, i, rest}

          <<char, _::binary>>, _rest ->
            raise ExoRedis.RESP.ProtocolError,
              message: "expected CRLF, found: #{inspect(<<char>>)}"
        end)
      end)
    end

    defp parse_integer_without_sign(<<non_digit, _::binary>>) do
      raise ExoRedis.RESP.ProtocolError,
        message: "expected integer, found: #{inspect(<<non_digit>>)}"
    end

    defp parse_integer_digits(<<digit, rest::binary>>, acc)
         when digit in ?0..?9,
         do: parse_integer_digits(rest, acc * 10 + (digit - ?0))

    defp parse_integer_digits(<<_non_digit, _::binary>> = rest, acc),
      do: {:ok, acc, rest}

    defp parse_integer_digits(<<>>, acc),
      do: {:continuation, &parse_integer_digits(&1, acc)}

    defp parse_bulk_string(rest) do
      resolve_cont(parse_integer(rest), fn
        -1, rest ->
          {:ok, nil, rest}

        size, rest ->
          parse_string_of_known_size(rest, size)
      end)
    end

    defp parse_string_of_known_size(data, size) do
      case data do
        <<str::bytes-size(size), @crlf, rest::binary>> ->
          {:ok, str, rest}

        _ ->
          {:continuation, &parse_string_of_known_size(data <> &1, size)}
      end
    end

    defp parse_array(rest) do
      resolve_cont(parse_integer(rest), fn
        -1, rest ->
          {:ok, nil, rest}

        size, rest ->
          take_elems(rest, size, [])
      end)
    end

    defp until_crlf(data, acc \\ "")

    defp until_crlf(<<@crlf, rest::binary>>, acc), do: {:ok, acc, rest}
    defp until_crlf(<<>>, acc), do: {:continuation, &until_crlf(&1, acc)}

    defp until_crlf(<<?\r>>, acc),
      do: {:continuation, &until_crlf(<<?\r, &1::binary>>, acc)}

    defp until_crlf(<<byte, rest::binary>>, acc),
      do: until_crlf(rest, <<acc::binary, byte>>)

    defp take_elems(data, 0, acc) do
      {:ok, Enum.reverse(acc), data}
    end

    defp take_elems(<<_, _::binary>> = data, n, acc) when n > 0 do
      resolve_cont(parse(data), fn elem, rest ->
        take_elems(rest, n - 1, [elem | acc])
      end)
    end

    defp take_elems(<<>>, n, acc) do
      {:continuation, &take_elems(&1, n, acc)}
    end

    defp resolve_cont({:ok, val, rest}, ok) when is_function(ok, 2),
      do: ok.(val, rest)

    defp resolve_cont({:continuation, cont}, ok),
      do: {:continuation, fn new_data -> resolve_cont(cont.(new_data), ok) end}
  end
end
