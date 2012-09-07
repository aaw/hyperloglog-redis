# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "hyperloglog-redis"
  gem.homepage = "http://github.com/aaw/hyperloglog-redis"
  gem.license = "MIT"
  gem.summary = %Q{An implementation of the HyperLogLog set cardinality estimation algorithm in Ruby using Redis as a back-end}
  gem.description = %Q{An implementation of the HyperLogLog set cardinality estimation algorithm in Ruby using Redis as a back-end}
  gem.email = "aaron.windsor@gmail.com"
  gem.authors = ["Aaron Windsor"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task :default => :spec
