# specs for defining commands
defmodule ExoRedis.Command.Spec do
  require Logger

  @callback min_required_args :: integer
  @callback name :: String.t()
  @callback optional_flags :: list(String.t())
  @callback args_required :: true | false
  @callback process_mod :: module()

  ######## internal methods

  defp fetch_spec_mods do
    #    {:ok, mods} = :application.get_key(:exo_redis, :modules)
    #
    #    mods
    #    |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "#{ExoRedis.Command.Spec}."))
    [
      ExoRedis.Command.Spec.Get,
      ExoRedis.Command.Spec.Set,
      ExoRedis.Command.Spec.Info,
      ExoRedis.Command.Spec.GetBit,
      ExoRedis.Command.Spec.SetBit,
      ExoRedis.Command.Spec.ZAdd,
      ExoRedis.Command.Spec.ZCard,
      ExoRedis.Command.Spec.ZRange,
      ExoRedis.Command.Spec.ZCount
    ]
  end

  defp load_metadata do
    mods = :ets.lookup(:metadata, :mods)[:mods]

    case mods do
      nil ->
        :ets.insert(:metadata, {:mods, [{:specs, fetch_spec_mods()}]})

      mod_meta ->
        if mod_meta[:specs] == nil do
          mod_meta_data =
            mod_meta
            |> Keyword.merge([{:specs, fetch_spec_mods()}])

          :ets.insert(:metadata, {:mods, mod_meta_data})
        end
    end

    :ets.lookup(:metadata, :mods)[:mods][:specs]
  end

  def get_spec(name) do
    command =
      load_metadata()
      |> Enum.filter(fn mod -> mod.name == name end)

    Logger.debug(fn -> "Spec for #{name}  :#{inspect(command)}" end)

    if length(command) > 0 do
      {:ok, hd(command)}
    else
      {:error,
       %ExoRedis.Server.Error{type: "Err", message: "Unknown type '#{name}'"}}
    end
  end
end
