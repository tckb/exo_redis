# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :exo_redis,
  # Server settings
  port: 15000,
  accept_pool: 2,
  rdb_file: "/path/to/file",
  # mark scans the entire table so beware of this!
  gc_mark_cycle: 500_000,
  gc_sweep_cycle: 300_000

import_config "#{Mix.env()}.exs"
