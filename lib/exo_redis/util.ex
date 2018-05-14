defmodule ExoRedis.Util do
  # the stdlib downcase is slow
  def downcase(x), do: downcase(x, [])

  def downcase(<<x, rest::bits>>, acc) when x >= ?A and x <= ?Z,
    do: downcase(rest, [x + 32 | acc])

  def downcase(<<x, rest::bits>>, acc), do: downcase(rest, [x | acc])
  def downcase(<<>>, acc), do: IO.iodata_to_binary(:lists.reverse(acc))

  def sigil_k(string, []), do: :xxhash.hash32(string)
end
