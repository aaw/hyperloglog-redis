hyperloglog-redis
=================

This gem is an implementation of the HyperLogLog algorithm for estimating 
cardinalities of sets observed via a stream of events. A [Redis](http://redis.io) 
instance is used for storing the counters. A simple example:

    require 'redis'
    require 'hyperloglog-redis'

    redis = Redis.new
    counter = HyperLogLog.new(redis)
    ['john', 'paul', 'george', 'ringo', 'john', 'paul'].each do |beatle|
      counter.add('beatles', beatle)
    end

    puts "There are approximately #{counter.count('beatles')} distinct Beatles"

You can also ask for an estimate from multiple counters and you'll get
an estimate of the size of their union:

    ['joe', 'denny', 'linda', 'jimmy', 'paul'].each do |wing_member|
      counter.add('wings', wing_member)
    end

    puts "There are approximately #{counter.count('beatles', 'wings')} people who were in the Beatles or Wings"

Each HyperLogLog counter uses a small, fixed amount of space but can
estimate the cardinality of any set of up to around a billion values with
relative error of about 1.04 / Math.sqrt(2 ** b), where b is a parameter
passed to the HyperLogLog initializer that defaults to 10. With b = 10, 
each counter is represented by a Redis sorted set with 2 ** b = 1024 values 
(a few KB of space) and we get an expected relative error of 3%. Contrast this 
with the amount of space needed to compute set cardinality exactly, which is 
over 100 MB for a even a bit vector representing a set with a billion values.

The basic idea of HyperLogLog (and its predecessors PCSA and LogLog) is to apply
a good hash function to each value you see in the stream and record the longest 
run of zeros that you've seen as a prefix of any hashed value. If the hash 
function is good, you'd expect that its bits are statistically independent, so 
seeing a value that starts with exactly X zeros should happen with probability 
2 ** -(X + 1). So if you've seen a run of 5 zeros in one of your hash values, 
you're likely to have around 2 ** 6 = 64 values in the underlying set. The actual 
implementation and analysis are much more advanced than this, but that's the idea.

The HyperLogLog algorithm is described and analyzed in the paper 
["HyperLogLog: the analysis of a near-optimal cardinality estimation 
algorithm"](http://algo.inria.fr/flajolet/Publications/FlFuGaMe07.pdf) 
by Flajolet, Fusy, Gandouet, and Meunier. Our implementation closely 
follows the program described in Section 4 of that paper.

Installation
============

    gem install hyperloglog-redis