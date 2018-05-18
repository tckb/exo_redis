defmodule ExoRedis.Application do
  @moduledoc """
   This is main module for the application.
  """
  use Application
  require Logger

  def start(_type, _args) do
    ExoRedis.Governer.Supervisor.start_link(name: ExoRedis.Supervisor)
  end
end
