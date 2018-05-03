defmodule ExoRedis.Server.GenServerHandler do
  require Logger
  alias ExoRedis.Command.Handler, as: CmdHandler

  use GenServer
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
  def handle_info(
        {:tcp, socket, @crlf},
        %{socket: socket, transport: transport} = state
      ) do
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

    resp =
      input
      |> CmdHandler.handle_command()

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

#
# defmodule ExoRedis.Server.SimpleHandler do
#  alias ExoRedis.Command.Handler, as: CmdHandler
#
#  def start_link(ref, socket, transport, opts) do
#    pid =
#      :proc_lib.spawn_link(__MODULE__, :init, [ref, socket, transport, opts])
#
#    {:ok, pid}
#  end
#
#  def init(ref, socket, transport, _Opts = []) do
#    :ok = :ranch.accept_ack(ref)
#    :ok = transport.setopts(socket, [{:nodelay, true}, {:reuseaddr, true}])
#    loop(socket, transport)
#  end
#
#  def loop(socket, transport) do
#    case transport.recv(socket, 0, 5000) do
#      {:ok, input} ->
#        resp =
#          input
#          |> CmdHandler.handle_command()
#
#        transport.send(socket, resp)
#        loop(socket, transport)
#
#      {:error, :closed} ->
#        :ok = transport.close(socket)
#
#      {:error, :timeout} ->
#        :ok = transport.close(socket)
#
#      # err_message
#      {:error, _} ->
#        :ok = transport.close(socket)
#    end
#  end
# end
# defmodule ExoRedis.Server.SimpleHandler2 do
#  alias ExoRedis.Command.Handler, as: CmdHandler
#
#  def start_link(ref, socket, transport, opts) do
#    responder_pid = spawn_link(__MODULE__, :responder, [socket, transport])
#
#    pid =
#      :proc_lib.spawn_link(__MODULE__, :init, [
#        ref,
#        socket,
#        transport,
#        responder_pid
#      ])
#
#    {:ok, pid}
#  end
#
#  def responder(socket, transport) do
#    receive do
#      {:message, packet} ->
#        # resp = packet |> CmdHandler.handle_command()
#        transport.send(socket, [43, "PONG", "\r\n"])
#        responder(socket, transport)
#    end
#  end
#
#  def init(ref, socket, transport, responder_pid) do
#    :ok = :ranch.accept_ack(ref)
#    :ok = transport.setopts(socket, [{:nodelay, true}, {:reuseaddr, true}])
#    loop(socket, transport, responder_pid)
#  end
#
#  def loop(socket, transport, responder) do
#    case transport.recv(socket, 0, 5000) do
#      {:ok, input} ->
#        send(responder, {:message, input})
#        loop(socket, transport, responder)
#
#      {:error, :closed} ->
#        :ok = transport.close(socket)
#
#      {:error, :timeout} ->
#        :ok = transport.close(socket)
#
#      # err_message
#      {:error, _} ->
#        :ok = transport.close(socket)
#    end
#  end
# end
