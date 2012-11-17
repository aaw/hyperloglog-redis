module HyperLogLog
  class TimeSeriesCounter
    include Algorithm

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
      max_length = raw_counters.map{ |c| c.length }.max
      combined_counters = raw_counters.map{ |c| c.fill(0, c.length, max_length - c.length) }.transpose.map{ |e| e.max.to_i }
      @redis.set(destination, combined_counters.pack('N*'))
    end
    
    def raw_union(counter_names, time=0)
      raw_counters = @redis.mget(*counter_names).compact
      return [] if raw_counters.none?
      hyperloglog_counters = raw_counters.map do |counter|
        slices = counter.unpack('N*').each_slice(@m).to_a
        slices.last.fill(0, slices.last.length, slices.first.length - slices.last.length)
        slices.transpose.map{ |x| x.rindex{ |c| c > time } || 0 }
      end
      return hyperloglog_counters.first if hyperloglog_counters.one?
      max_length = hyperloglog_counters.map{ |c| c.length }.max
      hyperloglog_counters.map{ |c| c.fill(0, c.length, max_length - c.length) }.transpose.map{ |e| e.max.to_i }
    end

  end
end
