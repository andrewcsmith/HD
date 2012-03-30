Notes about compatibility between HD & MM:

For the HD::Ratio class (not taking into account Harmonic Distance):
====================================================================

direction metrics:

No problems

combinatorial metrics:

MM::DistConfig
scale = :relative
intra_delta = :/.to_proc

ic metric:

irrelevant to this usage

Taking Harmonic Distance into account:
======================================

intra_delta = :distance

direction metrics:

This does not entirely make sense. Although, perhaps, distance decreasing or increasing?

ocm & ucm: no apparent problems
olm & ulm: currently, the two vectors must be the same length

The steps you must go through to change the prime weights:

(where hdc is an HD::HDConfig and c is an MM::DistConfig)

d = lambda {|m, n| m.distance(n, hdc)}
c.intra_delta = d
MM.vector_delta(m, c.order, c.intra_delta, nil) # => [ 1.584962500721156, 1.584962500721156, Infinity, Infinity ] 

SEARCH FUNCTIONS!
================

Currently, search functions don't work. The culprit seems to be mm.rb:1064-65. This method of using a discrete step size and adding it to each element of the current vector does not seem to work.

In the sense of harmonic distance, it may be difficult to change the step size like this. Adding or subtracting will greatly increase the harmonic distance, so this needs to be changed to * or /.

POSSIBLE SOLUTION:
==================

Index the list of tuneable intervals by harmonic distance. Need to find a linear way to traverse possible intervals to move by.

MM.find_point_at_distance({
:v1 => m, 
:d => 0.5, 
:dist_func => MM.olm, 
:search_opts => {:epsilon => 1.0, :start_step_size => HD::Ratio.new(16,15), :return_full_path => true},
:config => c, 
:allow_duplicates => true})

MM.metric_path({
:v1 => m,
:v2 => l,
:metric => MM.ocm,
:config => c,
:cheat => true
})