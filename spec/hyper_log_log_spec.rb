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

  it "produces acceptable estimates" do
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

end
