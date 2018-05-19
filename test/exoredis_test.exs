defmodule ExoRedis.BasicTests do
  use ExUnit.Case, async: true

  alias ExoRedis.StorageProcess
  alias ExoRedis.RESP.BinaryPacker
  alias ExoRedis.RESP.Parser
  alias ExoRedis.Command.Handler

  doctest ExoRedis.Util
  doctest ExoRedis.StorageProcess
  doctest ExoRedis.Commands

  test "sampleTest" do
    assert ExoRedis.Util.downcase_ascii("string") == "string"
  end

  test "cache expiry" do
    StorageProcess.put_data(:key1, :val1, {0, 500})
    :timer.sleep(1000)
    assert StorageProcess.get_data(:key1) == {:error, :not_found}
  end

  test "check set/get" do
    assert send_get_response(["set", "k1", "v1"]) == {:ok, "OK", ""}
    assert send_get_response(["get", "k1"]) == {:ok, "v1", ""}
  end

  test "check set/get bit" do
    # => 01000001 => "A"
    assert send_get_response(["set", "k1", "A"]) == {:ok, "OK", ""}
    assert send_get_response(["get", "k1"]) == {:ok, "A", ""}

    # => 01100001 => "a"
    assert send_get_response(["setbit", "k1", "2", "1"]) == {:ok, 0, ""}
    assert send_get_response(["get", "k1"]) == {:ok, "a", ""}

    # => 01110001 => "q"
    assert send_get_response(["setbit", "k1", "3", "1"]) == {:ok, 0, ""}
    assert send_get_response(["get", "k1"]) == {:ok, "q", ""}
  end

  defp send_get_response(request) do
    request
    |> BinaryPacker.pack()
    |> IO.iodata_to_binary()
    |> Handler.process_command()
    |> IO.iodata_to_binary()
    |> Parser.parse()
  end
end
