$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'redis'
require 'hyperloglog-redis'

db_number = ENV['REDIS_TEST_DATABASE'] || '15'
ENV['REDIS_URL'] = "redis://localhost:6379/#{db_number}"
redis = Redis.new
if redis.keys('*').length > 0
  puts "Warning! These specs use database #{db_number} on your local redis instance"
  puts "running on port 6379. Your database #{db_number} seems to have keys in it."
  puts "Please clear them before running the specs or set the environment"
  puts "variable REDIS_TEST_DATABASE to use a different database number."
  raise SystemExit
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.before(:each) do
    Redis.new.flushdb
  end
  config.after(:each) do
    Redis.new.flushdb
  end
end
