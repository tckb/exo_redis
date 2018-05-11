# ExoRedis

**Warn: Highly Experimental!**

This is an attempt to implement a clone of redis-server in elixir. Loads of missing pieces here, I will add the missing pieces as soon as I get time. Until then,  _Here lies the dragons!_ do not use for anything else than going through the code.


## Additions
- Commands are now accepted case agnostic

## Performance optimization
- removed external libraries for handling ets, used directly ets for fetching data
- removed additional lookups while inserting data
- added predefined "command_table" for looking up commands
  - removed specs, process all such nonsense
  - process_mods are pre-started, instead of lazily
  - dynamic supervisor is now a normal supervisor that starts all the command processes while bootup

### result

~57% performance gain is noted

## Benchmark

```
## Exo-Redis
ubuntu@system:~$ redis-benchmark -t set -n 1000000 -p 15000 -q
SET: 65282.68 requests per second

## Redis Server
ubuntu@system:~$ redis-benchmark -t set -n 1000000 -q
SET: 136184.12 requests per second
```
