defmodule ExoRedis.Command.Process do
  use Alias
  require Logger
  @callback process_command_args(list(any())) :: any()

  ####### Client Apis

  def spawn_command_process(
        process_mod,
        %Command{command: cmd} = command
      ) do
    Logger.debug(fn -> "#{cmd} spawned #{process_mod}" end)

    {process_mod, command}
    |> start_link
  end

  def process_command(
        {process_mod, %Command{command: command, args: args} = process_command}
      ) do
    Logger.debug(fn -> "#{inspect(process_mod)} handle_command #{command}" end)

    call_process_command({process_mod, process_command})
  end

  ###### Internal Apis

  defmacro __using__(_) do
    quote do
      use GenServer
      use Alias
      require Logger

      def start_link(state \\ []) do
        GenServer.start_link(__MODULE__, state, name: __MODULE__)
      end

      def handle_call(
            {:command_invoked, %Command{command: command, args: args}},
            _from,
            state
          ) do
        {
          :reply,
          __MODULE__.process_command_args(command, args)
          |> __MODULE__.pack_response(),
          state
        }
      end

      def pack_response(response) do
        Logger.debug(fn -> "packing response : #{inspect(response)}" end)

        case response do
          :nodata ->
            ProtocolPacker.nodata_reply()

          :null_array ->
            ProtocolPacker.null_array_reply()

          _ ->
            response
            |> ProtocolPacker.pack()
        end
      end

      def store(key, data) do
        store(key, data, %{expiry: [-1, 0], flag: :set})
      end

      def store(
            key,
            data,
            %{expiry: [seconds, mills], flag: set_flag} = additional_data
          ) do
        Logger.debug(fn ->
          "store: #{key} -> #{inspect(data)} additional_data: #{
            inspect(additional_data)
          }"
        end)

        response = exits?(key)

        case response do
          {:ok, :key_exits} ->
            case set_flag do
              :set ->
                InternalStorage.put_data(key, {__MODULE__, data}, [
                  seconds,
                  mills
                ])

                {:ok, :key_exits}

              :set_if_exists ->
                InternalStorage.put_data(key, {__MODULE__, data}, [
                  seconds,
                  mills
                ])

                {:ok, :key_exits}

              :set_if_not_exists ->
                {:error, :flag_failed}
            end

          {:error, :key_missing} ->
            case set_flag do
              :set ->
                InternalStorage.put_data(key, {__MODULE__, data}, [
                  seconds,
                  mills
                ])

                {:ok, :key_missing}

              :set_if_exists ->
                {:error, :flag_failed}

              :set_if_not_exists ->
                InternalStorage.put_data(key, {__MODULE__, data}, [
                  seconds,
                  mills
                ])

                {:ok, :key_missing}
            end

          _ ->
            response
        end
      end

      defp exits?(key) do
        case InternalStorage.is_key_present?(key) do
          {:ok, flag} ->
            if(flag) do
              {:ok, :key_exits}
            else
              {:error, :key_missing}
            end
        end
      end

      def retrieve(key) do
        case InternalStorage.get_data(key) do
          {:ok, {owner_type, data}} ->
            if owner_type == __MODULE__ do
              {:ok, data}
            else
              {:error, :key_type_error}
            end

          {:error, :not_found} ->
            {:error, :key_missing}
        end
      end
    end
  end

  defp start_link({mod, _} = process_command) do
    mod_pid = Process.whereis(mod)

    Logger.debug(fn ->
      "#{mod} start_link #{mod} mod_pid #{inspect(mod_pid)}"
    end)

    case mod_pid do
      nil ->
        {:ok, pid} = Command.ProcessSupervisor.register_command_processor(mod)

        Logger.debug(fn -> "#{mod} is running on #{inspect(pid)}" end)

      pid ->
        Logger.debug(fn -> "#{mod} is running on #{inspect(pid)}" end)
    end

    {:ok, process_command}
  end

  defp start_link([]) do
    {:error, "can't start"}
  end

  defp call_process_command({mod, command}) do
    Logger.debug(fn -> "#{mod} call_process_command #{inspect(command)}" end)

    GenServer.call(mod, {:command_invoked, command})
  end
end
