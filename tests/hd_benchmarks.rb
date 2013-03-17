require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'
require 'benchmark'

# TODO: Work all of these difference distances out by hand, to make sure that it's all correct. Right now, I'm just asserting that these things I've done today will stay the same.

v1 = HD::Ratio.from_s("1/1 2/1 3/2 2/3 16/9 32/27 8/3 2/1 3/1")
v2 = HD::Ratio.from_s("1/1 4/3 16/9 32/27 32/9 64/27 128/81 32/9 32/27")

# Harmonic Distance Configurations

d_config = HD::HDConfig.new

c_olm = MM::DistConfig.new
c_olm.scale = :absolute
# One the usage of a specified proc lets the user specify a config object to use (prime_weights, etc)
c_olm.intra_delta = MM.get_harmonic_distance_delta(d_config)
# At this point, we are in the logarithmic domain so we can resort to subtraction to find the difference
c_olm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]
# This doesn't hurt anything.
c_olm.int_func = MM::INTERVAL_FUNCTIONS[:pairs]

Benchmark.bm do |x|
  x.report {918.times do
    MM.dist_olm(v1,v2,c_olm)
  end}
end