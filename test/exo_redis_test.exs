defmodule ExoRedisTest do
  use ExUnit.Case
  doctest ExoRedis

  test "greets the world" do
    assert ExoRedis.hello() == :world
  end
end
