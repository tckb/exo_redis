defmodule ExoRedis.BasicTest do
  use ExUnit.Case
  doctest ExoRedis.Util

  test "sampleTest" do
    assert ExoRedis.Util.downcase_ascii("string") == "string"
  end
end

defmodule ExoRedis.BasicTests do
  use ExUnit.Case
  alias ExoRedis.StorageProcess
  doctest ExoRedis.StorageProcess
  doctest ExoRedis.Commands

  test "cache expiry" do
    StorageProcess.put_data(:key1, :val1, {0, 500})
    :timer.sleep(1000)
    assert StorageProcess.get_data(:key1) == {:error, :not_found}
  end
end
