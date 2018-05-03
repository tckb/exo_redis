defmodule ExoRedis.ServerKickStarter do
  use GenServer

  @listen_port Application.get_env(:exo_redis, :port)
  @connection_acceptor_pool_size Application.get_env(:exo_redis, :accept_pool)
  require Logger

  def start_link(state \\ []) do
    case :ranch.start_listener(
           :exo_redis_server,
           # reference of the server
           # acceptor pool
           100,
           # TCP protocol handler, default from 'ranch'
           :ranch_tcp,
           [port: @listen_port],
           # this is the connection, well technically this is a "handler"
           ExoRedis.Server.GenServerHandler,
           []
         ) do
      {:ok, pid} ->
        Logger.info("Starting ranch @#{@listen_port} pid: #{inspect(pid)}")
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
