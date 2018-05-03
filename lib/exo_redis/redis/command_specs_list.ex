defmodule ExoRedis.Command.Spec.Get do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 1
  def name, do: "GET"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.Binary
end

defmodule ExoRedis.Command.Spec.Set do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 2
  def name, do: "SET"
  def optional_flags, do: ["NX", "MX"]
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.Binary
end

defmodule ExoRedis.Command.Spec.Info do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 0
  def name, do: "INFO"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.Info
end

defmodule ExoRedis.Command.Spec.GetBit do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 1
  def name, do: "GETBIT"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.Binary
end

defmodule ExoRedis.Command.Spec.SetBit do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 1
  def name, do: "SETBIT"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.Binary
end

defmodule ExoRedis.Command.Spec.ZAdd do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 3
  def name, do: "ZADD"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.RBTree
end

defmodule ExoRedis.Command.Spec.ZCard do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 3
  def name, do: "ZCARD"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.RBTree
end

defmodule ExoRedis.Command.Spec.ZRange do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 3
  def name, do: "ZRANGE"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.RBTree
end

defmodule ExoRedis.Command.Spec.ZCount do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 3
  def name, do: "ZCOUNT"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.RBTree
end

defmodule ExoRedis.Command.Spec.Save do
  @behaviour ExoRedis.Command.Spec
  def min_required_args, do: 0
  def name, do: "SAVE"
  def optional_flags, do: []
  def args_required, do: min_required_args() > 0
  def process_mod, do: ExoRedis.Command.Process.SaveStorage
end
