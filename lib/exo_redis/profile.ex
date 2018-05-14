defmodule ExoRedis.Profile do
  import ExProf.Macro

  def do_analyze do
    profile do
      ExoRedis.Command.Handler.process_command(
        "*3\r\n$3\r\nset\r\n$2\r\nk1\r\n$2\r\nv1\r\n"
      )
    end
  end

  def do_profile do
    ExoRedis.Command.Handler.process_command(
      "*3\r\n$3\r\nset\r\n$2\r\nk1\r\n$2\r\nv1\r\n"
    )
  end

  def string_downcase_ascii do
    String.downcase("ABCDEFGHIJKLMNO", :ascii)
  end

  def run do
    {records, _block_result} = do_analyze
    total_percent = Enum.reduce(records, 0.0, &(&1.percent + &2))
    IO.puts("total = #{total_percent}")
  end

  def run_bench_2 do
    Benchee.run(
      %{
        "downcase - stdlib" => fn string ->
          String.downcase(string, :ascii)
        end,
        "downcase - pattern_match" => fn string -> downcase_ascii_patternMatch(string) end
      },
      warmup: 5,
      time: 10,
      memory_time: 5,
      inputs: %{
        "alpha:big - 26" => "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "empty - 0" => "",
        "alpha:small - 26" => "abcdefghijklmnopqrstuvwxyz",
        "ELXIR - 500" => String.duplicate("ELXIR", 100),
        "ELXIR - 5000" => String.duplicate("ELXIR", 1000),
        "elxir - 500" => String.duplicate("elxir", 100),
        "elxir - 5000" => String.duplicate("elxir", 1000),
        "@!# - 20" => "~!@#$%^&*()_+/<>;:,."
      },
      formatters: [
        Benchee.Formatters.HTML,
        Benchee.Formatters.Console
      ]
    )
  end

  def run_bench_3 do
    Benchee.run(
      %{
        "downcase_ascii_iodata" => fn string ->
          downcase_ascii_iodata(string)
        end,
        "downcase_ascii_patternMatch" => fn string -> downcase_ascii_patternMatch(string) end
      },
      warmup: 3,
      time: 10,
      memory_time: 10,
      inputs: %{
        "alpha" => "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "ELXIR - 5000" => String.duplicate("ELXIR", 1000),
        "elxir - 5000" => String.duplicate("elxir", 1000),
        "elXIr - 5000" => String.duplicate("elXIr", 1000)
      },
      formatters: [Benchee.Formatters.Console]
    )
  end

  def run_bench do
    :ets.new(:store4, [:set, :named_table])
    :ets.new(:store3, [:duplicate_bag, :named_table])
    :ets.insert(:store4, {"k1", "val1"})
    :ets.insert(:store3, {"k1", "val1"})

    Benchee.run(
      %{
        "ets_lookup" => fn -> :ets.lookup(:store4, "k1") end,
        "ets_insert" => fn -> :ets.lookup(:store4, {"k4", "val"}) end,
        "ets_lookup_db" => fn -> :ets.lookup(:store3, "k2") end,
        "ets_member" => fn -> :ets.member(:store4, "k1") end,
        "ets_member_db" => fn -> :ets.member(:store3, "k2") end
      },
      warmup: 5,
      time: 10,
      formatter_options: %{
        console: %{
          extended_statistics: true
        }
      }
    )
  end

  defp downcase_ascii_patternMatch(string), do: downcase_ascii(string, [])

  defp downcase_ascii(<<c, rest::bits>>, acc) when c >= ?A and c <= ?Z,
    do: downcase_ascii(rest, [c + 32 | acc])

  defp downcase_ascii(<<c, rest::bits>>, acc),
    do: downcase_ascii(rest, [c | acc])

  defp downcase_ascii(<<>>, acc), do: IO.iodata_to_binary(:lists.reverse(acc))

  def downcase_ascii_iodata(x), do: IO.iodata_to_binary(do_dn4(x))

  def do_dn4(<<x, rest::bits>>) when x >= ?A and x <= ?Z,
    do: [x + 32 | do_dn4(rest)]

  def do_dn4(<<x, rest::bits>>), do: [x | do_dn4(rest)]
  def do_dn4(<<>>), do: []
end
