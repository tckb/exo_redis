defmodule ExoRedis.Command.Process do
  use Alias
  require Logger

  ####### Client Apis

  def process_command({process_mod, %Command{} = process_command}) do
    Logger.debug(fn ->
      "process_command #{inspect(process_mod)} #{inspect(process_command)}"
    end)

    call_process_command({process_mod, process_command})
  end

  ###### Internal Apis

  defp call_process_command({mod, command}) do
    Logger.debug(fn -> "#{mod} call_process_command #{inspect(command)}" end)
    GenServer.call(mod, {:command_invoked, command})
  end

  ## macro starts
  @callback process_command_args(list(any())) :: any()

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

      @doc """
      stores the k,v data
      """
      def store(key, data) do
        store(key, data, %{expiry: [-1, 0], flag: :set})
      end

      @doc """
        stores the k,v pair based on the flag
      """
      def store(key, data, %{expiry: [seconds, mills], flag: set_flag}) do
        Logger.debug(fn ->
          "store: #{key} -> #{inspect(data)} expiry: #{seconds}.#{mills} :: #{
            set_flag
          }"
        end)

        case set_flag do
          :set ->
            # if this is set, then we don't care if the data exists or not, just set the data
            InternalStorage.put_data(key, {__MODULE__, data}, [
              seconds,
              mills
            ])

            {:ok, :success}

          :set_if_exists ->
            # sets only if the key exists!
            case exits?(key) do
              # key is present
              :key_exits ->
                InternalStorage.put_data(key, {__MODULE__, data}, [
                  seconds,
                  mills
                ])

                {:ok, :success}

              # anything else
              _ ->
                {:error, :flag_failed}
            end

          :set_if_not_exists ->
            # sets only if the key doesn't exist
            case exits?(key) do
              # key doesn't exists
              :key_missing ->
                InternalStorage.put_data(key, {__MODULE__, data}, [
                  seconds,
                  mills
                ])

                {:ok, :success}

              # anything else
              _ ->
                {:error, :flag_failed}
            end
        end
      end

      @doc """
       fetches the key data
      """
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

      defp exits?(key) do
        case InternalStorage.is_key_present?(key) do
          {:ok, flag} ->
            if(flag) do
              :key_exits
            else
              :key_missing
            end
        end
      end
    end
  end
end
