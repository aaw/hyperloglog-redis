require 'securerandom'
require 'timecop'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

MINUTES=60
HOURS=MINUTES*60
DAYS=HOURS*24
WEEKS=DAYS*7

describe HyperLogLog::TimeSeriesCounter do

  before(:each) do
    @b = 11
    @redis = Redis.new
    @counter = HyperLogLog::TimeSeriesCounter.new(@redis, @b)
    @expected_relative_error = 1.04 / Math.sqrt(2 ** @b)

    def counter_should_equal(counter_val, expected_val, relative_error_base=nil)
      (counter_val - expected_val).abs.should <= (relative_error_base || expected_val) * @expected_relative_error
    end
  end

  it "can estimate cardinalities from any particular point in time until the present" do
    Timecop.travel(Time.now - 2 * WEEKS) do
      (0..100).each { |i| @counter.add('mycounter', "item#{i}") }
    end
    Timecop.travel(Time.now - 1 * WEEKS) do
      (100..200).each { |i| @counter.add('mycounter', "item#{i}") }
    end
    Timecop.travel(Time.now - 6 * DAYS) do
      (0..100).each { |i| @counter.add('mycounter', "item#{i}") }
    end
    Timecop.travel(Time.now - 5 * DAYS) do
      (100..200).each { |i| @counter.add('mycounter', "item#{i}") }
    end
    Timecop.travel(Time.now - 4 * DAYS) do
      (200..250).each { |i| @counter.add('mycounter', "item#{i}") }
    end
    
    counter_should_equal(@counter.count('mycounter'), 250)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 3 * WEEKS), 250)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * WEEKS - 3 * DAYS), 250)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * WEEKS), 250)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 5 * DAYS - 12 * HOURS), 150, 250)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 4 * DAYS - 12 * HOURS), 50, 250)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 3 * DAYS), 0, 250)
  end

  it "can estimate unions from any particular point in time until the present" do
    Timecop.travel(Time.now - 2 * WEEKS) do
      (0..100).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 1 * WEEKS) do
      (100..200).each { |i| @counter.add('mycounter2', "item#{i}") }
    end
    Timecop.travel(Time.now - 6 * DAYS) do
      (0..100).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 5 * DAYS) do
      (100..200).each { |i| @counter.add('mycounter2', "item#{i}") }
    end
    Timecop.travel(Time.now - 4 * DAYS) do
      (200..250).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    
    counter_should_equal(@counter.union(['mycounter1', 'mycounter2']), 250)
    counter_should_equal(@counter.union(['mycounter1', 'mycounter2'], Time.now.to_i - 3 * WEEKS), 250)
    counter_should_equal(@counter.union(['mycounter1', 'mycounter2'], Time.now.to_i - 1 * WEEKS - 3 * DAYS), 250)
    counter_should_equal(@counter.union(['mycounter1', 'mycounter2'], Time.now.to_i - 1 * WEEKS), 250)
    counter_should_equal(@counter.union(['mycounter1', 'mycounter2'], Time.now.to_i - 5 * DAYS - 12 * HOURS), 150, 250)
    counter_should_equal(@counter.union(['mycounter1', 'mycounter2'], Time.now.to_i - 4 * DAYS - 12 * HOURS), 50, 250)
    counter_should_equal(@counter.union(['mycounter1', 'mycounter2'], Time.now.to_i - 3 * DAYS), 0, 250)
  end

  it "can estimate intersections from any particular point in time until the present" do
    Timecop.travel(Time.now - 2 * WEEKS) do
      (0..100).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 1 * WEEKS) do
      (100..200).each { |i| @counter.add('mycounter2', "item#{i}") }
    end
    Timecop.travel(Time.now - 6 * DAYS) do
      (0..100).each { |i| @counter.add('mycounter2', "item#{i}") }
    end
    Timecop.travel(Time.now - 5 * DAYS) do
      (100..200).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 4 * DAYS) do
      (200..250).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 3 * DAYS) do
      (200..250).each { |i| @counter.add('mycounter2', "item#{i}") }
    end
    
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2']), 250)
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2'], Time.now.to_i - 3 * WEEKS), 250)
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2'], Time.now.to_i - 1 * WEEKS - 3 * DAYS), 150, 250)
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2'], Time.now.to_i - 6 * DAYS - 12 * HOURS), 50, 250)
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2'], Time.now.to_i - 5 * DAYS - 12 * HOURS), 50, 250)
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2'], Time.now.to_i - 4 * DAYS - 12 * HOURS), 50, 250)
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2'], Time.now.to_i - 3 * DAYS - 12 * HOURS), 0, 250)
    counter_should_equal(@counter.intersection(['mycounter1', 'mycounter2'], Time.now.to_i - 2 * DAYS), 0, 250)
  end

  it "can use union_store to store snapshots of counters at particular points in time" do
    Timecop.travel(Time.now - 2 * WEEKS) do
      (0..100).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 1 * WEEKS) do
      (100..200).each { |i| @counter.add('mycounter2', "item#{i}") }
    end
    Timecop.travel(Time.now - 6 * DAYS) do
      (0..100).each { |i| @counter.add('mycounter2', "item#{i}") }
    end
    Timecop.travel(Time.now - 5 * DAYS) do
      (100..200).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 4 * DAYS) do
      (200..250).each { |i| @counter.add('mycounter1', "item#{i}") }
    end
    Timecop.travel(Time.now - 3 * DAYS) do
      (200..250).each { |i| @counter.add('mycounter2', "item#{i}") }
    end

    @counter.union_store('counter1_1_week_ago', ['mycounter1'], Time.now.to_i - 1 * WEEKS)
    @counter.union_store('counter2_5_days_ago', ['mycounter2'], Time.now.to_i - 5 * DAYS)
    counter_should_equal(@counter.union(['counter1_1_week_ago', 'counter2_5_days_ago']), 150, 250)
  end

  it "allows you to override the time an event is registered when it's added" do
    (0..1000).each { |i| @counter.add('mycounter', "item#{i}", Time.now.to_i - 3 * WEEKS) }
    (1000..2000).each { |i| @counter.add('mycounter', "item#{i}", Time.now.to_i - 2 * WEEKS) }
    (2000..3000).each { |i| @counter.add('mycounter', "item#{i}", Time.now.to_i - 1 * WEEKS) }
    (3000..4000).each { |i| @counter.add('mycounter', "item#{i}") }
    
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 4 * WEEKS), 4000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 2 * WEEKS - 3 * DAYS), 3000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * WEEKS - 3 * DAYS), 2000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 3 * DAYS), 1000)
  end

  it "doesn't screw up more recent counts when items are injected with earlier timestamp overrides" do
    Timecop.travel(Time.now - 3 * WEEKS) do
      (0..1000).each { |i| @counter.add('mycounter', "item#{i}") }
    end
    
    Timecop.travel(Time.now - 2 * WEEKS) do
      (1000..2000).each { |i| @counter.add('mycounter', "item#{i}") }
    end

    Timecop.travel(Time.now - 1 * WEEKS) do
      (2000..3000).each { |i| @counter.add('mycounter', "item#{i}") }
    end

    Timecop.travel(Time.now - 2 * DAYS) do
      (1000..2000).each { |i| @counter.add('mycounter', "item#{i}") }
    end

    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 4 * WEEKS), 3000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 2 * WEEKS - 3 * DAYS), 2000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * WEEKS - 3 * DAYS), 2000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 3 * DAYS), 1000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * DAYS), 0)
    
    # Shouldn't change counts, since they're updates to counts that happen later
    # than the time we're trying to inject
    (1000..2000).each { |i| @counter.add('mycounter', "item#{i}", Time.now.to_i - 1 * WEEKS) }

    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 4 * WEEKS), 3000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 2 * WEEKS - 3 * DAYS), 2000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * WEEKS - 3 * DAYS), 2000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 3 * DAYS), 1000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * DAYS), 0)

    # Should change counts, since they're updates to counts for items we've never
    # seen before in the past
    (3000..4000).each { |i| @counter.add('mycounter', "item#{i}", Time.now.to_i - 1 * WEEKS) }

    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 4 * WEEKS), 4000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 2 * WEEKS - 3 * DAYS), 3000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * WEEKS - 3 * DAYS), 3000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 3 * DAYS), 1000)
    counter_should_equal(@counter.count('mycounter', Time.now.to_i - 1 * DAYS), 0)
  end

  it "can compute deltas over time on events correctly" do
    # A larger-scale test that simulates user join events and tests that we can get 
    # week-by-week deltas. Generate new user counts according to the following 
    # weekly schedule: 55780 during the first week, 300 more during the next week, 
    # 10 more the next week, etc.

    schedule = [55780, 300, 10, 4000, 1000, 1000, 5000, 15000, 30000, 3000]
    schedule.each_with_index do |num_users, i|
      Timecop.travel(Time.now - (schedule.length * WEEKS) + (i * WEEKS)) do
        num_users.times do |i|
          Timecop.travel(Time.now + 2 * HOURS + i) do
            @counter.add("users", "user#{SecureRandom.uuid}")
          end
        end
      end
    end

    actual_total = schedule.reduce(:+) 
    estimated_total = @counter.count("users")
    (actual_total - estimated_total).abs.should < @expected_relative_error * actual_total

    # Go through the schedule, computing week-by-week deltas and comparing them to the
    # scheduled additions. 

    schedule.each_with_index do |users_joined, i|
      week = schedule.length - 1 - i
      c = @counter.count('users', Time.now.to_i - (week+1) * WEEKS) - @counter.count('users', Time.now.to_i - week * WEEKS)
      (users_joined - c).abs.should < @expected_relative_error * schedule.reduce(:+)
    end
  end
end
