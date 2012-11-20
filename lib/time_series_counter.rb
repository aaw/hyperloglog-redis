module HyperLogLog
  class TimeSeriesCounter
    include Algorithm

    # This is an implementation of HyperLogLog that allows for querying counts
    # within time ranges of the form (t, current_time] with second-level
    # granularity. The standard implementation of HyperLogLog stores the max
    # number of leading zeros seen in the image of each of 2 ** b hash 
    # functions. These counts can naturally be stored in a string of length
    # 2 ** b by allocating one byte per leading zero count.
    #
    # To provide counts within a time range, we alter the standard
    # implementation to store a mapping of pairs of the form (hash function,
    # leading zero count) -> timestamp, where the mapping (h,z) -> t represents
    # the fact that we observed z leading zeros in the image of hash function h
    # most recently at time t. This mapping is stored in a string by packing
    # 4-byte words (timestamps, represented in seconds since the epoch) into
    # a matrix indexed by hash function and zero count stored in row-major
    # order. Since the max zero count for a counter with parameter b is (32-b),
    # this representation takes up at most 4 * (32-b) * (2 ** b) bytes (and
    # usually much less, since we don't allocate space for rows corresponding
    # to higher leading zero counts until they're actaully observed.)
    #
    # To convert this representation to a HyperLogLog counter for the time
    # range (t, current_time], we simply filter out all timestamps less than t
    # in the matrix and then find, for each hash function, the maximum z for 
    # which that hash function has a non-zero timestamp.

    def add(counter_name, value, time=nil)
      hash, function_name, new_value = hash_info(value)
      index = 4 * (function_name + (new_value.to_i * @m))
      if time.nil?
        @redis.setrange(counter_name, index, [Time.now.to_i].pack('N'))
      else
        existing_time = @redis.getrange(counter_name, index, index + 3)
        existing_val = existing_time.empty? ? 0 : existing_time.unpack('N').first
        @redis.setrange(counter_name, index, [time.to_i].pack('N')) if time.to_i > existing_val 
      end
    end

    # Estimate the cardinality of a single set
    def count(counter_name, time=0)
      union_helper([counter_name], time)
    end
    
    # Estimate the cardinality of the union of several sets
    def union(counter_names, time=0)
      union_helper(counter_names, time)
    end    
    
    # Store the union of several sets in *destination* so that it can be used as 
    # a HyperLogLog counter later.
    def union_store(destination, counter_names, time=0)
      raw_counters = @redis.mget(*counter_names).compact.map{ |c| c.unpack('N*').map{ |x| x > time ? x : 0 } }
      combined_counters = jagged_transpose(raw_counters).map{ |x| x.max.to_i }
      @redis.set(destination, combined_counters.pack('N*'))
    end

    private
    
    def raw_union(counter_names, time=0)
      raw_counters = @redis.mget(*counter_names).compact
      return [] if raw_counters.none?
      hyperloglog_counters = raw_counters.map do |counter|
        jagged_transpose(counter.unpack('N*').each_slice(@m).to_a).map{ |x| x.rindex{ |c| c > time } || 0 }
      end
      return hyperloglog_counters.first if hyperloglog_counters.one?
      jagged_transpose(hyperloglog_counters).map{ |x| x.max.to_i }
    end

    # Given an array of non-uniform length arrays, right-pad all arrays with 
    # zeros so they're the same size, then transpose the array. This is a 
    # destructive operation: the zero-padding modifies the array-of-arrays
    def jagged_transpose(arrays)
      max_length = arrays.map{ |a| a.length }.max
      arrays.map{ |a| a.fill(0, a.length, max_length - a.length) }.transpose
    end

  end
end
