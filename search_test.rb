require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'

require 'io'

output = File.new('./topology-iii.txt', 'a')

# Theme from a cryptozoology
# start_point = NArray[HD.r, HD.r(4,3), HD.r(16,9), HD.r(32,27), HD.r(8,3), HD.r(4,3)]
# start_point = NArray[HD.r, HD.r(4,3), HD.r(16,9), HD.r(32,27), HD.r(8,3), HD.r(2,1), HD.r(3,2)]
start_point = HD::Ratio.from_s("1/1 2/1 3/2 2/3 16/9 32/27 8/3 2/1 3/1")
# end_point = NArray.object(7).fill!(HD::Ratio.new)
#start_point = NArray.to_na(HD::Ratio.from_s("[1/1, 4/3, 16/9, 32/27, 32/9, 64/27, 128/81, 32/9, 32/27, 16/3, 32/9, 128/27]"))

banned_points = nil
# banned_points = [HD::Ratio.from_s("[1/1, 4/3, 16/9, 32/27, 32/9, 64/27, 128/81, 32/9, 32/27, 16/3, 32/9, 128/27]"]

# No alterations to the HDConfig
d_config = HD::HDConfig.new
d_config.prime_weights = [2,3,2,7]

# d_config.tuneable.reject! {|x| x.to_f > 4.0}

if !MM.all_tuneable?(start_point, d_config.tuneable)
  raise Exception.new("NO WAY. START POINT IS NOT TUNEABLE DUDE.\n #{start_point.to_a}")
end

# Wrap all tuneable intervals to within an octave
# d_config.tuneable.collect! do |x| 
#   while x.to_f >= 2.0
#     x = x * HD.r(1,2)
#   end
#   x
# end

d_config.tuneable.uniq!

c_ocm = MM::DistConfig.new
c_ocm.scale = :absolute # We're concerned with the leaps in harmonic distance overall
c_ocm.intra_delta = MM.get_harmonic_distance_delta(d_config) # We pass the HDConfig to the intra_delta
# The HDConfig is embedded within the intra_delta, which allows it to travel together, and also allows us to continue modifying d_config from the outside.
c_ocm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff] # At this point, we are in the logarithmic domain so we can resort to linear difference

c_olm = MM::DistConfig.new
c_olm.scale = :absolute
c_olm.intra_delta = MM.get_harmonic_distance_delta(d_config)
# At this point, we are in the logarithmic domain so we can resort to subtraction to find the difference
c_olm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]
c_olm.int_func = MM::INTERVAL_FUNCTIONS[:pairs]

c_ocd = MM::DistConfig.new

mm = MM.get_multimetric([{:metric => MM.ocm, :config => c_ocm, :weight => 0.6}, {:metric => MM.ocd, :config => c_ocd, :weight => 0.4}])

# distance = MM.dist_ocm(start_point, end_point, c_ocm) # => 0.349203096128918
distance = 0.3
puts "Attempting to pivot around the origin at a distance of #{distance}"

point_opts = {
  :v1 => start_point,
  :d => distance,
  :dist_func => MM.ocm,
  :config => c_ocm,
  :search_func => MM.get_hd_search,
  :search_opts => {
    :hd_config => d_config,
    :config => c_ocm,
    :epsilon => 0.01,
    :check_tuneable => true,
    :return_full_path => true,
    :max_iterations => 100,
    :banned => banned_points
  }
}


winner = MM.find_point_at_distance(point_opts)
winner[0] == nil ? exit : false

output.puts "path:"
winner.each {|x| output.puts "#{x.to_a}"}
intervals = []
for i in 1...winner[winner.size-1][0].total
  intervals << winner[winner.size-1][0][i-1] / winner[winner.size-1][0][i]
end
output.puts "\nStats: prime_weights #{d_config.prime_weights}; distance #{distance}"
output.puts "We found a winner: #{winner[winner.size-1].to_a}"
output.puts "Distance: #{MM.dist_ocm(winner[winner.size-1][0], start_point, c_ocm)}"
output.puts "Inner intervals: #{intervals}\n\n"