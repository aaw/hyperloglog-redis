hyperloglog-redis
=================

This gem is a pure Ruby implementation of the HyperLogLog algorithm for estimating 
cardinalities of sets observed via a stream of events. A [Redis](http://redis.io) 
instance is used for storing the counters. A minimal example:

    require 'redis'
    require 'hyperloglog-redis'

    counter = HyperLogLog::Counter.new(Redis.new)
    ['john', 'paul', 'george', 'ringo', 'john', 'paul'].each do |beatle|
      counter.add('beatles', beatle)
    end

    puts "There are approximately #{counter.count('beatles')} distinct Beatles"

Each HyperLogLog counter uses a small, fixed amount of space but can
estimate the cardinality of any set of up to around a billion values with
relative error of 1.04 / Math.sqrt(2 ** b) with high probability, where b is a 
parameter passed to the `HyperLogLog::Counter` initializer that defaults to 10. 
With b = 10, each counter is represented by a 1 KB string in Redis and we get 
an expected relative error of 3%. Contrast this with the amount of space needed 
to compute set cardinality exactly, which is over 100 MB for a even a bit vector 
representing a set with a billion values.

The basic idea of HyperLogLog (and its predecessors PCSA, LogLog, and others) is 
to apply a good hash function to each value observed in the stream and record the longest 
run of zeros seen as a prefix of any hashed value. If the hash 
function is good, the bits in any hashed value should be close to statistically independent, 
so seeing a value that starts with exactly X zeros should happen with probability close to
2 ** -(X + 1). So, if you've seen a run of 5 zeros in one of your hash values, 
you're likely to have around 2 ** 6 = 64 values in the underlying set. The actual 
implementation and analysis are much more advanced than this, but that's the idea.

This gem implements a few useful extensions to the basic HyperLogLog algorithm
which allow you to estimate unions and intersections of counters as well as
counts within specific time ranges. These extensions are described in detail below.

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

    puts "There are approximately #{counter.union(['beatles', 'wings'])} people who were in the Beatles or Wings"

The same relative error guarantee above applies to unions: a union of
size N can be estimated to within +/- N * (1.04 / Math.sqrt(2 ** b)) elements,
regardless of how many HyperLogLog counters that union spans. You can store 
a unioned counter for querying or combining later with `union_store`:

    counter.union_store('all_beatles_and_wings_members', ['beatles', 'wings'])
    
    puts "There are approximately #{counter.count('all_beatles_and_wings_members'}} people who were in the Beatles or Wings"

Intersections can also be estimated:

    puts "There are approximately #{counter.intersection(['beatles', 'wings'])} people who were in both the Beatles and Wings"

However, intersections of HyperLogLog counters are calculated indirectly via the
[inclusion/exclusion principle](http://en.wikipedia.org/wiki/Inclusion%E2%80%93exclusion_principle)
as a sum of unions and there aren't good theoretical bounds on the error of that sum. In
practice, the estimates that come out of small intersections tend to follow the
same relative error patterns, but beware using this type of estimation on intersections
of large numbers of sets, both because the errors can be much larger than those guaranteed
for unions and the complexity of computing intersections grows exponentially with 
the number of sets in the intersection.

Set cardinality within a time interval
======================================

All examples up until now use `HyperLogLog::Counter`, which stores HyperLogLog
counters as (2 ** b)-byte Redis strings. hyperloglog-redis also contains the counter implementation
`HyperLogLog::TimeSeriesCounter`, which uses a little more space (Redis strings of up to 
4 * (32 - b) * (2 ** b) bytes) but allows you to estimate the cardinality of sets during 
certain time windows.

Using `HyperLogLog::TimeSeriesCounter`, you can get estimates of the number of distinct
elements added to a set in the past X seconds, for any value of X. A `HyperLogLog::TimeSeriesCounter`
is initialized with the same arguments as a regular `Counter` but implements a
superset of `HyperLogLog::Counter`'s interface. Namely, each of the methods `add`,
`count`, `union`, `intersection`, and `union_store` take an optional final time argument,
either a Ruby `Time` or an integer representing seconds since the epoch. 

When passed a time argument t, `add` registers an addition to the set at time t. When no
time is passed, the current system time is used. The methods `count`, `union`,
`intersection`, and `union_store` all estimate set cardinality for the time interval 
consisting of all events that happened after time t when t is passed as a final argument.

For example, to get the number of distinct user logins within the
past week, we might call:

    one_week = 60 * 60 * 24 * 7
    logins_in_past_week = counter.count('user_logins', Time.now - one_week)

A note about relative errors
============================

With a parameter `b` in the range [4..16], HyperLogLog counters provide a relative
error of 1.04/sqrt(2 ** b) with high probability. When unions, intersections, and
time range queries are involved, it's sometimes not clear what the relative error
is relative to, so here is some clarification:

* For a union of counters, the relative error applies to the size of the union. Taking
the union of counters is lossless in the sense that you end up with the same counter
you would have arrived at had you observed the union of all of the individual events.

* For an intersection of counters, there's no good theoretical bound on the relative
error. In practice, the relative error is largely a function of the relative size of
the sets, the amount they overlap, and the number of sets being intersected. If the
error of any term in the inclusion-exclusion formula is as large as the intersection
cardinality, then the estimate will be useless. For the best results, intersect only
two or three sets of roughly the same size. For instance, given two sets whose
cardinalities are within one order of magnitude and whose intersection is roughly 10%
of the smaller set, the error (relative to the true intersection cardinality) would be
about 10-30%.

* For time queries, the relative error applies to the size of the set within the time
range you've queried. For example, given a set of cardinality 1,000,000 that has had
100 distinct additions within the last 10 minutes, if you observe such a set with a
HyperLogLog counter with parameter b=10 (3% relative error), you can expect the count
returned from a query about the last 10 minutes to be within 3 of 100.

Comparison to other approaches
==============================

When trying to optimize for space, two well-known alternatives to HyperLogLog exist:

* Bit vectors: you provide some near-perfect hash function between keys in your domain
and an interval of integers, then represent that interval of integers with bits.
* Bloom filters with counters: use a [Bloom filter](http://en.wikipedia.org/wiki/Bloom_filter) 
to keep track of items seen; on insert, when the Bloom filter tells you that the item
seen is not in the set, increment the counter.

Both bit vectors and bloom filters can be augmented to hold timestamps for entries in the
data structures and simulate counters for time-ranges like `HyperLogLog::TimeSeriesCounter`.

Bit vectors give exact counts, but the space complexity is linear with the size of
the set, and you must either allocate a large bit vector upfront or cope with the complexity
of dynamically resizing your bit vector as the set grows. Providing a manual mapping from
members of your set to an interval of integers is sometimes a non-trivial task. Counts,
unions, and intersections are all linear-time operations in the size of the universe of
the set being represented.

Bloom filters can be much more compact than bit vectors, but the actual count associated
with a Bloom filter is an artifact of the construction of the data structure, so the cost
of estimating a union or intersection is linear in the size of the Bloom filter. Getting
high probability guarantees on the quality of the estimate of Bloom filter counts requires
several "good" hash functions that have some degree of independence from each other; in 
practice, coming up with several independent implementations of good hash functions is 
difficult. Bloom filters require that all of their space be allocated upfront (re-hashing
isn't possible without replaying all events), so in practice you need some estimate of
how large the counters are going to be before allocating the counter.

HyperLogLog counters take up less space than either of the above approaches and provide
constant-time implementations (in the size of the sets being represented) of unions,
intersections, and time range queries. A `HyperLogLog::Counter` with parameter b will
be stored in a Redis string of length at most 2 ** b bytes, whereas a `HyperLogLog::TimeSeriesCounter` with parameter
b will be stored in a Redis string of length at most 4 * (32 - b) * (2 ** b) bytes. For counters representing smaller sets,
the size taken up by a `HyperLogLog::TimeSeriesCounter` can be significantly less. Here
are some examples for specific values of b:

* With b = 7, a `HyperLogLog::Counter` uses at most 128 bytes and a `HyperLogLog::TimeSeriesCounter` uses at most 13 KB while providing a relative error of 9%.
* With b = 11, a `HyperLogLog::Counter` uses at most 2 KB and a `HyperLogLog::TimeSeriesCounter` uses at most 168 KB while providing a relative error of 2%
* With b = 16, a `HyperLogLog::Counter` uses at most 64 KB and a `HyperLogLog::TimeSeriesCounter` uses at most 4 MB while providing a relative error of less than half a percent.

Installation
============

    gem install hyperloglog-redis
