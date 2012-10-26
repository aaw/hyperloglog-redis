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

Unions and intersections
========================

You can also ask for an estimate of the union from multiple counters:

    ['joe', 'denny', 'linda', 'jimmy', 'paul'].each do |wings_member|
      counter.add('wings', wings_member)
    end

    puts "There are approximately #{counter.union('beatles', 'wings')} people who were in the Beatles or Wings"

The same relative error guarantee above applies to unions: a union of
size N can be estimated to within N * (1.04 / Math.sqrt(2 ** b)) elements,
regardless of how many HyperLogLog counters that union spans. You can store 
a unioned counter for querying or combining later with `union_store`:

    counter.union_store('all_beatles_and_wings_members', 'beatles', 'wings')
    
    puts "There are approximately #{counter.count('all_beatles_and_wings_members'}} people who were in the Beatles or Wings"

Intersections can also be estimated:

    puts "There are approximately #{counter.intersection('beatles', 'wings')} people who were in both the Beatles and Wings"

However, intersections of HyperLogLog counters are calculated indirectly via the
[inclusion/exclusion principle](http://en.wikipedia.org/wiki/Inclusion%E2%80%93exclusion_principle)
as a sum of unions and there aren't good theoretical bounds on the error of that sum. In
practice, the estimates that come out of small intersections tend to follow the
same relative error patterns, but beware using this type of estimation on large
intersections, both because the errors can be much larger than those guaranteed
for unions and the complexity of computing intersections grows exponentially with 
the number of counters being intersected.

Installation
============

    gem install hyperloglog-redis