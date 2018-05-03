# ExoRedis

**Warn: Highly Experimental!**

This is an attempt to implement a clone of redis-server in elixir. Loads of missing pieces here, I will add the missing pieces as soon as I get time. Until then,  _Here lies the dragons!_ do not use for anything else than going through the code. 

## Benchmark

```
## Exo-Redis
ubuntu@system:~$ redis-benchmark -t set,ping -n 1000000 -p 15000 -q
PING_INLINE: 139236.98 requests per second <- fully optimized pings ;)
PING_BULK: 138888.89 requests per second
SET: 41481.73 requests per second <- this sucks but haven't optimized it

## Redis Server
ubuntu@system:~$ redis-benchmark -t set,ping -n 1000000  -q
PING_INLINE: 134282.27 requests per second
PING_BULK: 134210.17 requests per second
SET: 137551.58 requests per second
```


