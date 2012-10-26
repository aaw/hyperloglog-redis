require 'redis'
require 'murmurhash3'

class HyperLogLog
  def initialize(redis, b=10)
    raise "Accuracy not supported. Please choose a value of b between 4 and 16" if b < 4 || b > 16
    @redis = redis
    @bits_in_hash = 32 - b
    @m = (2 ** b).to_i
    if @m == 16
      @alpha = 0.673
    elsif @m == 32
      @alpha = 0.697
    elsif @m == 64
      @alpha = 0.709
    else
      @alpha = 0.7213/(1 + 1.079/@m)
    end
  end

  def add(counter_name, value)
    hash = MurmurHash3::V32.murmur3_32_str_hash(value)
    function_name = hash % @m
    w = hash / @m
    existing_value = (@redis.hget(counter_name, function_name) || 0).to_i
    new_value = [existing_value, rho(w)].max
    @redis.hset(counter_name, function_name, new_value) if new_value > existing_value
  end

  # Estimate the cardinality of a single set
  def count(counter_name)
    union_helper([counter_name])
  end

  # Estimate the cardinality of the union of several sets
  def union(*counter_names)
    union_helper(counter_names)
  end

  # Store the union of several sets in *destination* so that it can be used as 
  # a HyperLogLog counter later.
  def union_store(destination, *counter_names)
    raw_union(counter_names).each do |key, count|
      @redis.hset(destination, key, count)
    end
  end

  # Estimate the cardinality of the intersection of several sets. We do this by 
  # using the principle of inclusion and exclusion to represent the size of the
  # intersection as the alternating sum of an exponential number of 
  # cardinalities of unions of smaller sets.
  def intersection(*counter_names)
    icount = (1..counter_names.length).map do |k|
      counter_names.combination(k).map do |group|
        ((k % 2 == 0) ? -1 : 1) * union_helper(group)
      end.inject(0, :+)
    end.inject(0, :+)
    [icount, 0].max
  end

  def union_helper(counter_names)
    all_estimates = raw_union(counter_names).map{ |value, score| 2 ** -score }
    estimate_sum = all_estimates.reduce(:+) || 0
    estimate = @alpha * @m * @m * ((estimate_sum + @m - all_estimates.length) ** -1)
    if estimate <= 2.5 * @m
      if all_estimates.length == @m
        estimate.round
      else # Correction for small sets
        (@m * Math.log(Float(@m)/(@m - all_estimates.length))).round
      end
    elsif estimate <= 2 ** 32 / 30.0
      estimate.round
    else # Correction for large sets
      (-2**32 * Math.log(1 - estimate/(2.0**32))).round
    end
  end

  def raw_union(counter_names)
    counter_names.map{ |counter_name| @redis.hgetall(counter_name).map{ |x,y| [x, y.to_i] } }
                 .reduce(:concat)
                 .group_by{ |key, count| key }
                 .map{ |key, counters| [key, counters.map{ |x| x.last }.max] }
  end

  # rho(i) is the position of the first 1 in the binary representation of i,
  # reading from most significant to least significant bits. Some examples:
  # rho(1...) = 1, rho(001...) = 3, rho(000...0) = @bits_in_hash + 1
  def rho(i)
    if i == 0
      @bits_in_hash + 1 
    else
      @bits_in_hash - Math.log(i, 2).floor
    end
  end

end
