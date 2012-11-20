module HyperLogLog
  class Counter
    include Algorithm

    # This is the implementation of the standard HyperLogLog algorithm, storing 
    # counts in each byte of a string of length 2 ** b. 

    def add(counter_name, value)
      hash, function_name, new_value = hash_info(value)
      existing_value = @redis.getrange(counter_name, function_name, function_name).unpack('C').first.to_i
      @redis.setrange(counter_name, function_name, new_value.chr) if new_value > existing_value
    end

    # Estimate the cardinality of a single set
    def count(counter_name)
      union_helper([counter_name])
    end
    
    # Estimate the cardinality of the union of several sets
    def union(counter_names)
      union_helper(counter_names)
    end    
    
    # Store the union of several sets in *destination* so that it can be used as 
    # a HyperLogLog counter later.
    def union_store(destination, counter_names)
      @redis.set(destination, raw_union(counter_names).inject('') {|a, e| a << e.chr})
    end

    private
    
    def raw_union(counter_names, time=nil)
      counters = @redis.mget(*counter_names).compact
      return [] if counters.none?
      return counters.first.each_byte if counters.one?
      counters.map{|c| c.unpack("C#{@m}")}.transpose.map {|e| e.compact.max.to_i}
    end
    
  end
end
