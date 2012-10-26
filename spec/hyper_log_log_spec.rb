require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe HyperLogLog do

  it "doesn't change its count when it sees values that it's already seen" do
    redis = Redis.new
    counter = HyperLogLog.new(redis, 10)
    test_set = (1..100).map{ |x| x.to_s }
    test_set.each{ |value| counter.add("mycounter", value) }
    original_estimate = counter.count("mycounter")
    5.times do 
      test_set.each do |value|
        counter.add("mycounter", value)
        counter.count("mycounter").should == original_estimate
      end
    end
  end

  it "can maintain more than one logically distinct counter" do
    redis = Redis.new
    counter = HyperLogLog.new(redis, 10)
    other_estimate = counter.count("counter2")
    (1..100).each do |i| 
      counter.add("counter1", i.to_s)
      counter.count("counter2").should == other_estimate
    end
    other_estimate = counter.count("counter1")
    (101..200).each do |i| 
      counter.add("counter2", i.to_s)
      counter.count("counter1").should == other_estimate
    end
    other_estimate = counter.count("counter2")
    (201..300).each do |i| 
      counter.add("counter1", i.to_s)
      counter.count("counter2").should == other_estimate
    end 
    counter.count("counter1").should > 100
    counter.count("counter2").should > 50
    counter.count("counter1").should > counter.count("counter2")
  end

  it "can exactly count small sets" do
    redis = Redis.new
    counter = HyperLogLog.new(redis, 11)
    10.times { |i| counter.add("mycounter", i.to_s) }
    counter.count("mycounter").should == 10
  end

  it "can exactly count small unions" do
    redis = Redis.new
    counter = HyperLogLog.new(redis, 11)
    (1..8).each { |i| counter.add("mycounter1", i.to_s) }
    (5..12).each { |i| counter.add("mycounter2", i.to_s) }
    counter.union("mycounter1", "mycounter2").should == 12
  end

  it "can exactly count small intersections" do
    redis = Redis.new
    counter = HyperLogLog.new(redis, 11)
    (1..8).each { |i| counter.add("mycounter1", i.to_s) }
    (5..12).each { |i| counter.add("mycounter2", i.to_s) }
    counter.intersection("mycounter1", "mycounter2").should == 4
  end

  it "can store unions for querying later" do
    redis = Redis.new
    counter = HyperLogLog.new(redis, 11)
    (1..10).each { |i| counter.add("mycounter1", i.to_s) }
    (5..15).each { |i| counter.add("mycounter2", i.to_s) }
    (15..25).each { |i| counter.add("mycounter3", i.to_s) }
    (20..50).each { |i| counter.add("mycounter4", i.to_s) }
    counter.union_store("aggregate_counter", "mycounter1", "mycounter2", "mycounter3", "mycounter4")
    counter.union("mycounter1", "mycounter2", "mycounter3", "mycounter4").should == counter.count("aggregate_counter")
  end

  # With parameter b, HyperLogLog should produce estimates that have
  # relative error of 1.04 / Math.sqrt(2 ** b). Of course, this analysis
  # is based on assumptions that aren't necessarily true in practice and
  # the observed relative error will depend on the distribution of data
  # we receive as well as the interaction of the murmur hash implementation
  # with that data. Keeping that in mind, the following spec makes sure 
  # that in the process of adding 1000 values to a set, HyperLogLog only 
  # gives bad estimates (more than twice the expected relative error) in 
  # less than 1% of the cases and never gives very bad estimates (more than
  # three times the expected relative error.)
  #
  # It's fine to fudge these numbers a little if the implementation changes,
  # since you can clearly find a different set of values that make this test 
  # fail even without changing the implementation. But it should serve as a 
  # good indication that there aren't any logical errors in the HyperLogLog
  # implementation, since it exercises all of the cases in HyperLogLog's
  # count method except for the correction for very large set sizes.

  it "produces acceptable estimates for counts" do
    max_items = 1000
    redis = Redis.new
    (6..16).each do |b|
      counter = HyperLogLog.new(redis, b)
      redis.del('mycounter')
      bad_estimates = 0
      very_bad_estimates = 0
      expected_relative_error = 1.04 / Math.sqrt(2 ** b)
      max_items.times do |i|
        value = Digest::MD5.hexdigest("value#{i}")
        counter.add("mycounter", value)
        actual = i + 1
        approximate = counter.count("mycounter")
        relative_error = (actual - approximate).abs / Float(actual)
        bad_estimates += 1 if relative_error > expected_relative_error * 2
        very_bad_estimates += 1 if relative_error > expected_relative_error * 3
      end
      bad_estimates.should < max_items / 100.00
      very_bad_estimates.should == 0
    end
  end

  it "produces acceptable estimates for unions with few elements in common" do
    b, max_items = 10, 2000
    counter = HyperLogLog.new(Redis.new, b)
    bad_estimates = 0
    very_bad_estimates = 0
    expected_relative_error = 1.04 / Math.sqrt(2 ** b)
    max_items.times do |i|
      value1 = Digest::MD5.hexdigest("value#{i}")
      counter.add("mycounter1", value1)
      value2 = Digest::MD5.hexdigest("value#{i}incounter2")
      counter.add("mycounter2", value2)
      value3 = Digest::MD5.hexdigest("this is value#{i}")
      counter.add("mycounter3", value3)
      actual = 3 * (i + 1)
      approximate = counter.union("mycounter1", "mycounter2", "mycounter3")
      relative_error = (actual - approximate).abs / Float(actual)
      bad_estimates += 1 if relative_error > expected_relative_error * 2
      very_bad_estimates += 1 if relative_error > expected_relative_error * 3
    end
    bad_estimates.should < (3 * max_items) / 100.00
    very_bad_estimates.should == 0
  end

  it "produces acceptable estimates for unions with many elements in common" do
    b, max_items, intersection_size = 10, 1000, 2000
    counter = HyperLogLog.new(Redis.new, b)
    bad_estimates = 0
    very_bad_estimates = 0
    expected_relative_error = 1.04 / Math.sqrt(2 ** b)

    intersection_size.times do |i|
      value = Digest::MD5.hexdigest("test#{i}value")
      ['mycounter1', 'mycounter2', 'mycounter3'].each do |counter_name|
        counter.add(counter_name, value)
      end
    end

    max_items.times do |i|
      value1 = Digest::MD5.hexdigest("value#{i}")
      counter.add("mycounter1", value1)
      value2 = Digest::MD5.hexdigest("value#{i}isincounter2")
      counter.add("mycounter2", value2)
      value3 = Digest::MD5.hexdigest("this is value#{i}")
      counter.add("mycounter3", value3)
      actual = 3 * (i + 1) + intersection_size
      approximate = counter.union("mycounter1", "mycounter2", "mycounter3")
      relative_error = (actual - approximate).abs / Float(actual)
      bad_estimates += 1 if relative_error > expected_relative_error * 2
      very_bad_estimates += 1 if relative_error > expected_relative_error * 3
    end

    bad_estimates.should < ((3 * max_items) + intersection_size) / 100.00
    very_bad_estimates.should == 0
  end

  # There are no good theoretical guarantees that I know of for arbitrary
  # intersection estimation, since it's expessed as the sum of unions of
  # HyperLogLog counters, but it tends to work okay in practice, as seen below.

  it "produces decent estimates for intersections" do
    b, max_items = 6, 1000
    counter = HyperLogLog.new(Redis.new, b)
    expected_relative_error = 1.04 / Math.sqrt(2 ** b)

    max_items.times do |i|
      value1 = Digest::MD5.hexdigest("first-value#{i}")
      value2 = Digest::MD5.hexdigest("second-value#{i}")
      value3 = Digest::MD5.hexdigest("third-value#{i}")
      value4 = Digest::MD5.hexdigest("fourth-value#{i}")
      counter.add("mycounter1", value1)
      counter.add("mycounter2", value2)
      counter.add("mycounter3", value3)
      counter.add("mycounter4", value4)
      [value1, value2, value3, value4].each{ |value| counter.add("mycounter5", value) }
    end

    small_counters = ['mycounter1', 'mycounter2', 'mycounter3', 'mycounter4']
    
    small_counters.each do |counter_name|
      intersection_estimate = counter.intersection(counter_name, 'mycounter5')
      intersection_estimate.should > 0
      (intersection_estimate - counter.count(counter_name)).abs.should < max_items * expected_relative_error
    end

    [2,3].each do |intersection_size|
      small_counters.combination(intersection_size).each do |counter_names|
        intersection_estimate = counter.intersection(*counter_names)
        intersection_estimate.should >= 0
        intersection_estimate.should < intersection_size * max_items * expected_relative_error
      end
    end

    100.times do |i|
      value = Digest::MD5.hexdigest("somethingintheintersection#{i}")
      small_counters.each { |counter_name| counter.add(counter_name, value) }
    end

    [2,3,4].each do |intersection_size|
      small_counters.combination(intersection_size).each do |counter_names|
        intersection_estimate = counter.intersection(*counter_names)
        intersection_estimate.should >= 0
        (intersection_estimate - 100).abs.should < intersection_size * (max_items + 100) * expected_relative_error
      end
    end

  end

end
