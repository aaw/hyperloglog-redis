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

