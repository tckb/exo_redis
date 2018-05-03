defmodule ExoRedis.Storage.RDB do
  defmodule Encoder do
  end

  defmodule Decoder do
    # 10 byte metadata
    # 5 bytes
    @redis_signature <<"REDIS"::utf8>>
    # 4 bytes - big endian
    @version <<3::big-size(24)>>
    # 1 byte
    @db_selector <<254::size(8)>>

    def read_metadata(
          <<@redis_signature, version::big-size(24), @db_selector,
            actual_data::bitstring>>
        ) do
    end
  end
end
