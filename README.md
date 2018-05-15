# ExoRedis

**Warn: Highly Experimental!**

This is an attempt to implement a clone of redis-server in elixir. Loads of missing pieces here, I will add the missing pieces as soon as I get time. Until then,  _Here lies the dragons!_ do not use for anything else than going through the code.

## Additions

-   Commands are now accepted case agnostic

## Performance optimization

-   removed external libraries for handling ets, used directly ets for fetching data
-   removed additional lookups while inserting data
-   added predefined "command_table" for looking up commands
    -   removed specs, process all such nonsense
    -   process_mods are pre-started, instead of lazily
    -   dynamic supervisor is now a normal supervisor that starts all the command processes while bootup

### more optimizations

-   reduced the acceptor pool size to 2 from 100

    -   this reduces un necessary context switching for accepting new connections.
    -   this improved the overall throughput

-   added `:async` mode for `:set` command

    -   Instead of using `GenServer.call`  used `GenServer.cast` for setting a simple key & value

### result

// yet to be done

## Benchmark

 // yet to be done
