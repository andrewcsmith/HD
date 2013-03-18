require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'

# Demonstration of the following procedure:
# Index of tuneable intervals based on the likely distance that they will move the given point. 

# A tuneable interval's mean score is computed as follows:
# Given an n-dimensional vector, every n-sized repeating combination of the set {-1, 0, 1} is computed. We will refer to this set of combinations as q. A summation is taken of the current vector multiplied by a vector filled with the given tuneable interval raised to the q power. This sum is divided by the size of set q for the interval's mean score.

# This score is used to index all the tuneable intervals based on how far they are likely to move the current point in harmonic space. The given step size, which will decrease logarithmically with each failed iteration, is used as a goal. The tuneable interval that will be used to find the next point will be the one that gives the largest possible score under the step size threshold. 

metric = MM.ocm
current_point = NArray[HD.r, HD.r(3,2), HD.r(5,4), HD.r(5,3), HD.r(4,3), HD.r(8,7), HD.r]

hd_config = HD::HDConfig.new
hd_config.prime_weights = [2,3,5,7]
# I choose 3.0 (rather than 2.0) so that it's possible to incorporate ratios such as 9/8 that aren't considered "tuneable intervals." Of course, it's also possible to just use 3/2 and 3/2, but that requires too many steps.
hd_config.tuneable.reject! {|x| x.to_f > 3.0}

# DistConfig alterations:
c_ocm = MM::DistConfig.new
c_ocm.scale = :absolute # We're concerned with the leaps in harmonic distance overall
# One the usage of a specified proc lets the user specify a config object to use (prime_weights, etc)
c_ocm.intra_delta = MM.get_harmonic_distance_delta(hd_config) # We pass the HDConfig to the intra_delta
# At this point, we are in the logarithmic domain so we can resort to subtraction to find the difference
c_ocm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]

tuneable = hd_config.tuneable
tuneable.reject! {|x| (x.distance(HD.r, hd_config) ** -1) == 0}
tuneable.sort_by! {|x| x.distance(HD.r, hd_config)}

tuneable.each {|t| puts "#{t}\t#{t.distance(HD.r, hd_config)}"}
tuneable_scores = []

candidates = [-1, 0, 1]
# We need a list of possible alterations the length of the current vector
all_candidates = candidates.repeated_combination(current_point.total).to_a

# Create a score for every tuneable interval
for i in 0...tuneable.size
  interval_score = 0.0
  # For each possible combination of exponents, 
  for j in 0...all_candidates.size
    interval_score += metric.call(current_point, current_point * (tuneable[i] ** all_candidates[j]), c_ocm)
  end
  interval_score /= all_candidates.size
  tuneable_scores << [tuneable[i], interval_score]
end

tuneable_scores.sort_by! {|x| x[1]}
tuneable_scores.each {|x| puts "Interval: #{x[0]}\t\tScore: #{x[1]}"}