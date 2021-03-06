defmodule ExoRedis.ServerKickStarter do
  @moduledoc """
  the process responsible for kick starting the TCP server
  """
  @listen_port Application.get_env(:exo_redis, :port)
  @connection_acceptor_pool_size Application.get_env(:exo_redis, :accept_pool)

  use GenServer
  require Logger

  def start_link(state \\ []) do
    case :ranch.start_listener(
           # reference of the server
           :exo_redis_server,
           # acceptor pool
           @connection_acceptor_pool_size,
           # TCP protocol handler, default from 'ranch'
           :ranch_tcp,
           [
             {:port, @listen_port},
             {:max_connections, :infinity}
           ],
           # this is the connection, well technically this is a "handler"
           ExoRedis.Server.GenServerHandler,
           []
         ) do
      {:ok, pid} ->
        Logger.info("Started listener @#{@listen_port} pid: #{inspect(pid)}")
        {:ok, pid}

      {:error, err_msg} ->
        {:stop, {:error, err_msg}, []}
    end

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end
end
