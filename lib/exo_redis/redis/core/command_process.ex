defmodule ExoRedis.Command.Process do
  require Logger
  import ExoRedis.Command
  alias ExoRedis.StorageProcess
  alias ExoRedis.RESP.BinaryPacker

  ####### Client Apis

  def process_command({process_mod, redis_command() = process_command}) do
    Logger.debug(fn ->
      "process_command #{inspect(process_mod)} #{inspect(process_command)}"
    end)

    GenServer.call(process_mod, {:command_invoked, process_command})
  end

  ## macro starts
  @callback process_command_args(list(any())) :: any()

  defmacro __using__(_) do
    quote do
      use GenServer
      require Logger

      def start_link(state \\ []) do
        GenServer.start_link(__MODULE__, state, name: __MODULE__)
      end

      def handle_call(
            {:command_invoked, redis_command(type: command_type, args: command_args)},
            _from,
            state
          ) do
        {
          :reply,
          __MODULE__.process_command_args(command_type, command_args)
          |> __MODULE__.pack_response(),
          state
        }
      end

      def store(key, data) do
        store(key, data, expiry: {-1, 0}, flag: :set)
      end

      def store(key, data, expiry: ttl, flag: set_flag) do
        do_store(key, data, ttl, set_flag)
      end

      defp do_store(key, data, ttl, set_flag) do
        Logger.debug(fn ->
          "store: #{key} -> #{inspect(data)} expiry: #{inspect(ttl)} :: #{set_flag}"
        end)

        case set_flag do
          :set ->
            # if this is set, then we don't care if the data exists or not, just set the data
            StorageProcess.put_data(key, {__MODULE__, data}, ttl, :async)
            {:ok, :success}

          :set_if_exists ->
            # sets only if the key exists!
            case exits?(key) do
              # key is present
              :key_exits ->
                StorageProcess.put_data(key, {__MODULE__, data}, ttl, :async)
                {:ok, :success}

              _ ->
                {:error, :flag_failed}
            end

          :set_if_not_exists ->
            # sets only if the key doesn't exist
            case exits?(key) do
              # key doesn't exists
              :key_missing ->
                StorageProcess.put_data(key, {__MODULE__, data}, ttl)
                {:ok, :success}

              # anything else
              _ ->
                {:error, :flag_failed}
            end
        end
      end

      def retrieve(key) do
        case StorageProcess.get_data(key) do
          {:ok, {__MODULE__, data}} -> {:ok, data}
          {:error, :not_found} -> {:error, :key_missing}
          _ -> {:error, :key_type_error}
        end
      end

      def exits?(key) do
        case StorageProcess.is_key_present?(key) do
          {:ok, true} -> :key_exits
          {:ok, false} -> :key_missing
        end
      end

      def pack_response(response) do
        Logger.debug(fn -> "packing response : #{inspect(response)}" end)

        case response do
          :nodata ->
            BinaryPacker.nodata_reply()

          :null_array ->
            BinaryPacker.null_array_reply()

          _ ->
            BinaryPacker.pack(response)
        end
      end
    end
  end
end
