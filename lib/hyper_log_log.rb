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
     function_name = (hash % @m).to_s
     w = hash / @m
     max_run_of_zeros = @redis.zscore(counter_name, function_name)
     @redis.zadd(counter_name, [(max_run_of_zeros || 0), rho(w)].max, function_name)
  end

  def count(counter_name)
    all_estimates = @redis.zrange(counter_name, 0, -1, {withscores: true})
    estimate_sum = all_estimates.map{ |f, score| 2 ** -score }.reduce(:+) || 0
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
