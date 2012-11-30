## 2.0.0 (11/30/2012)

* Changed the underlying storage from Redis hashes to bitstrings [simonkro](https://github.com/simonkro)
  If you have existing counters stored from version 1.0.0, you can upgrade them with 
  the following method:

        def upgrade_1_2(counter, redis)
          return if redis.type(counter) == "string"
          sketch = redis.hgetall(counter)
	  redis.del(counter)
          sketch.each{ |key, value| redis.setrange(counter, key.to_i, value.to_i.chr) }
        end

* Moved main counter implementation from `HyperLogLog` to the class `HyperLogLog::Counter`

* Added `HyperLogLog::TimeSeriesCounter` a counter type that can estimate cardinalities 
  for all events from a particular point in the past until the present.


## 1.0.0 (10/26/2012)

* Changed the underlying storage from Redis sorted sets to Redis hashes. This
  is a breaking change, if you have existing counters stored from earlier
  versions of this library, you can upgrade them with something like the
  following method:

        def upgrade(counter, redis)
          return if redis.type(counter) == "hash"
          values = redis.zrange(counter, 0, -1, {withscores: true})
          redis.del(counter)
          values.each { |key, value| redis.hset(counter, key, value.to_i) }
        end

* Added union_store command, which stores the results of a union for querying
  or combining with other sets later

