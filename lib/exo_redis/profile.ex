defmodule ExoRedis.Profile do
  import ExProf.Macro

  def do_analyze do
    profile do
      ExoRedis.Command.Handler.handle_command(
        "*3\r\n$3\r\nset\r\n$2\r\nk1\r\n$2\r\nv1\r\n"
      )
    end
  end

  def run do
    {records, _block_result} = do_analyze
    total_percent = Enum.reduce(records, 0.0, &(&1.percent + &2))
    IO.puts("total = #{total_percent}")
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
end
