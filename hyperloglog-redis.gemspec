# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "hyperloglog-redis"
  s.version = "2.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Aaron Windsor"]
  s.date = "2012-11-30"
  s.description = "An implementation of the HyperLogLog set cardinality estimation algorithm in Ruby using Redis as a back-end"
  s.email = "aaron.windsor@gmail.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "HISTORY.md",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "VERSION",
    "hyperloglog-redis.gemspec",
    "lib/algorithm.rb",
    "lib/counter.rb",
    "lib/hyperloglog-redis.rb",
    "lib/time_series_counter.rb",
    "spec/hyper_log_log_spec.rb",
    "spec/spec_helper.rb",
    "spec/time_series_counter_spec.rb"
  ]
  s.homepage = "http://github.com/aaw/hyperloglog-redis"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "An implementation of the HyperLogLog set cardinality estimation algorithm in Ruby using Redis as a back-end"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<murmurhash3>, ["~> 0.1.3"])
      s.add_runtime_dependency(%q<redis>, ["~> 3.0.1"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_development_dependency(%q<rake>, ["~> 0.9.2.2"])
      s.add_development_dependency(%q<rspec>, ["~> 2.11.0"])
      s.add_development_dependency(%q<timecop>, ["~> 0.5.3"])
    else
      s.add_dependency(%q<murmurhash3>, ["~> 0.1.3"])
      s.add_dependency(%q<redis>, ["~> 3.0.1"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_dependency(%q<rake>, ["~> 0.9.2.2"])
      s.add_dependency(%q<rspec>, ["~> 2.11.0"])
      s.add_dependency(%q<timecop>, ["~> 0.5.3"])
    end
  else
    s.add_dependency(%q<murmurhash3>, ["~> 0.1.3"])
    s.add_dependency(%q<redis>, ["~> 3.0.1"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    s.add_dependency(%q<rake>, ["~> 0.9.2.2"])
    s.add_dependency(%q<rspec>, ["~> 2.11.0"])
    s.add_dependency(%q<timecop>, ["~> 0.5.3"])
  end
end

