defmodule ExoRedis.Util do
  @moduledoc """
    contains util methods
  """
  @doc ~S"""
   performs downcasing for ascii string. the stdlib `String.downcase(string,:ascii)` is found to be less performant.
   This is fixed in the coming versions of elixir

   ## Examples
        iex> ExoRedis.Util.downcase_ascii("AbCdef")
        "abcdef"
        iex> ExoRedis.Util.downcase_ascii("")
        ""
        iex> ExoRedis.Util.downcase_ascii("acdef")
        "acdef"
        iex> ExoRedis.Util.downcase_ascii("acdef")
        "acdef"
  """
  @spec downcase_ascii(String.t()) :: String.t()
  def downcase_ascii(string) when is_binary(string) do
    IO.iodata_to_binary(do_downcase(string))
  end

  defp do_downcase(<<char, rest::bits>>) when char >= ?A and char <= ?Z,
    do: [char + 32 | do_downcase(rest)]

  defp do_downcase(<<char, rest::bits>>), do: [char | do_downcase(rest)]
  defp do_downcase(<<>>), do: []

  def sigil_k(string, []), do: :xxhash.hash32(string)
end
