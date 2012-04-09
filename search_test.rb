require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'

# I'm trying to get the Ordered Combinatorial Metrics search working properly

# Our starting point.

#end_point = NArray[HD.r, HD.r(4,3), HD.r(16,9), HD.r(32,27), HD.r(8,3), HD.r(4,3)]
# Theme from a cryptozoology
start_point = NArray[HD.r(2,1), HD.r(11,8), HD.r(11,6), HD.r(4,3), HD.r(2,1), HD.r(11,8), HD.r(3,2), HD.r(11,6), HD.r(4,3), HD.r(3,2)]

# No alterations to the HDConfig
d_config = HD::HDConfig.new
d_config.prime_weights = [2,3,5,7,11]

#d_config.tuneable.reject! {|x| x.to_f > 4.0}

d_config.tuneable << HD.r(11,8) << HD.r(16,11) << HD.r(12,11) << HD.r(11,9) << HD.r(9,8)
d_config.tuneable.sort!

puts "#{d_config.tuneable}"
puts "Start point tuneable? #{MM.all_tuneable?(start_point, d_config.tuneable)}"

# Wrap all tuneable intervals to within an octave
# d_config.tuneable.collect! do |x| 
#   while x.to_f >= 2.0
#     x = x * HD.r(1,2)
#   end
#   x
# end

d_config.tuneable.uniq!

# DistConfig alterations:
c_ocm = MM::DistConfig.new
c_ocm.scale = :absolute # We're concerned with the leaps in harmonic distance overall
# One the usage of a specified proc lets the user specify a config object to use (prime_weights, etc)
c_ocm.intra_delta = MM.get_harmonic_distance_delta(d_config) # We pass the HDConfig to the intra_delta
# At this point, we are in the logarithmic domain so we can resort to subtraction to find the difference
c_ocm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]

c_olm = MM::DistConfig.new
c_olm.scale = :absolute
c_olm.intra_delta = MM.get_harmonic_distance_delta(d_config)
# At this point, we are in the logarithmic domain so we can resort to subtraction to find the difference
c_olm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]

c_ocd = MM::DistConfig.new

mm = MM.get_multimetric([{:metric => MM.ocm, :config => c_ocm, :weight => 0.6}, {:metric => MM.ocd, :config => c_ocd, :weight => 0.4}])

#distance = MM.dist_olm(start_point, end_point, c_ocm) # => 0.2956437247418459
#puts distance
distance = 0.3

point_opts = {
  :v1 => start_point,
  :d => distance,
  :dist_func => MM.ocm,
  :config => c_ocm,
  :search_func => MM.get_hd_search,
  :search_opts => {
    :hd_config => d_config,
    :config => c_ocm,
    :epsilon => 0.05,
    :check_tuneable => true,
    :return_full_path => true,
    :step_size_subtract => 0.05,
    :max_iterations => 1000
  }
}
# 
# metric_path_opts = {}
# metric_path_opts[:v1] = start_point
# metric_path_opts[:v2] = end_point
# metric_path_opts[:metric] = MM.ocm
# metric_path_opts[:config] = c_ocm
# metric_path_opts[:euclidian_tightness] = 0.0
# metric_path_opts[:search_func] = MM.get_hd_search
# metric_path_opts[:search_opts] = point_opts[:search_opts]
# metric_path_opts[:print_stats] = false

winner = MM.find_point_at_distance(point_opts)
# winner = MM.metric_path(metric_path_opts)
puts "PATH:"
winner.each {|x| puts "#{x.to_a}"}
intervals = []
for i in 1...winner[winner.size-1].total
  intervals << winner[winner.size-1][i-1] / winner[winner.size-1][i]
end
puts "\nWe found a winner: #{winner[winner.size-1].to_a}"
puts "Inner intervals: #{intervals}"
puts "Target Distance: #{distance}"
puts "Achieved Distance: #{MM.dist_ocm(start_point, winner[winner.size-1], c_ocm)}"