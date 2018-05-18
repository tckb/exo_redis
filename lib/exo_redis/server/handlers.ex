defmodule ExoRedis.Server.GenServerHandler do
  @moduledoc """
  the handler responsible for handling the incoming commands
  """
  use GenServer
  alias ExoRedis.Command.Handler
  require Logger

  @behaviour :ranch_protocol
  @crlf "\r\n"
  @pong [43, "PONG", "\r\n"]

  def start_link(ref, socket, transport, _opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [ref, socket, transport])
    {:ok, pid}
  end

  @doc """
    socket initilization
  """
  def init(ref, socket, transport) do
    :ok = :ranch.accept_ack(ref)

    :ok =
      transport.setopts(socket, [
        # we want to receieve the data as it comes, push, instead of pull
        {:active, true},
        # enable TCP_NO_DELAY
        {:nodelay, true},
        # enable SOCKET REUSEADDR
        {:reuseaddr, true}
      ])

    :gen_server.enter_loop(__MODULE__, [], %{
      socket: socket,
      transport: transport
    })
  end

  @doc """
     don't reply to empty lines
  """
  def handle_info({:tcp, _socket, @crlf}, state) do
    {:noreply, state}
  end

  @doc """
    ping in-line replies
  """
  def handle_info(
        {:tcp, socket, "PING" <> @crlf},
        %{socket: socket, transport: transport} = state
      ) do
    Logger.debug(fn -> "PING_INLINE" end)

    transport.send(socket, @pong)
    {:noreply, state}
  end

  @doc """
   ping bulk replies
  """
  def handle_info(
        {:tcp, socket, <<_::binary-size(8)>> <> "PING" <> @crlf},
        %{socket: socket, transport: transport} = state
      ) do
    Logger.debug(fn -> "PING_BULK" end)

    transport.send(socket, @pong)
    {:noreply, state}
  end

  @doc """
   this is the proper input
  """
  def handle_info(
        {:tcp, socket, input},
        %{socket: socket, transport: transport} = state
      ) do
    Logger.debug(fn -> "received: #{inspect(input)}" end)

    resp = Handler.process_command(input)

    Logger.debug(fn ->
      "#{inspect(input)} -> #{resp |> IO.iodata_to_binary() |> inspect}"
    end)

    transport.send(socket, resp)
    {:noreply, state}
  end

  @doc """
   when the client disconnects
  """
  def handle_info(
        {:tcp_closed, socket},
        %{socket: socket, transport: transport} = state
      ) do
    transport.close(socket)
    {:stop, :normal, state}
  end
end
