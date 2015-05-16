# fluent-plugin-redis-pfcount

# fluent-plugin-redis-pfcount

Fluentd output plugin to measure cardinality by HyperLogLog Distinct Value Estimator implemented by Redis.


## Requirements

- Redis 2.8.9 or later
- redis-rb 3.0.0 or later


## Usage
Minimum configuration
```
<match apache.accesslog>
  type redis_pfcount
  distinct_attr host
</match>
```

More options
```
<match apache.*>
  type redis_pfcount

  ## redis server
  url "redis://127.0.0.1:6379/0"

  # host 127.0.0.1
  # port 6379
  # db_number 0
  # path /tmp/redis.sock

  ## record attribute to estimate cardinality
  distinct_attr host

  ## prefix redis key
  # "*" will be replaced by tag
  key_prefix "pfcount:*:"

  ## append time in strftime format
  key_with_time "%Y-%m-%d:"

  ## append value from record
  key_attr status

  # will generate
  # pfcount:apache.accesslog:2015-05-16:200

  ## emit record to next output plugin with new tag
  # "*" will be replaced by tag
  emit_tag unique.accesslog

  ## set PFCOUNT result into record
  emit_pfcount pfcount

  ## set true if PFADD altered HLL
  emit_changed changed

  ## do not emit records that did not alter HLL
  drop_unchanged true

</match>
```
It will gather daily unique visitor for each http status code, then emit one's first request to next output plugin.


## Limitation

- `PFADD` and `PFCOUNT` are pipelined but are NOT executed atomically. `PFCOUNT` is NOT guranteed to be sequential.
- Records may be duplicated when `emit` operation to next output plugin failed. Make sure the plugin is buffered or put UUID into record to deduplicate later.



## License

Apache License, Version 2.0



