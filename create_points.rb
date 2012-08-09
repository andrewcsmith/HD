t = Time.now

require '../Morphological-Metrics/mm.rb'
require './hd.rb'
require './deltas.rb'
require 'set'
require './get_angle.rb'

output = File.new("./points.txt", "w")

# Convenience method for determining whether or not all the intervals are tuneable
# Provide it with a point to test and an array of tuneable intervals (HD::Ratio objects)
def all_tuneable?(point, tuneable = HD::HDConfig.new.tuneable, range = [HD.r(2,3), HD.r(16,3)])
  if !point.is_a? NArray
    ArgumentError.new("Supplied #{point.class} to all_tuneable?")
  end
  for i in 0...point.shape[1]
    m = HD::Ratio[*point[true,i]]
    # Using the same variable name to note intervals that are out of range
    # (Default range settings are for the violin)
    if (m < range[0] || m > range[1]) 
      # puts "input is too #{(m < range[0]) ? "low" : "high"}"
      return false
    end
    # If it's the first interval, we don't care about tuneability
    i == 0 ? next : n = HD::Ratio[*point[true,i-1]]
    # This is the actual tuneability part
    # interval = m / n
    begin
      ((tuneable.include? m / n) || (tuneable.include? n / m)) ? next : (return false)
    rescue RangeError => e
      # puts e.message
      return false
    end
  end
  true
end

output_file = File.new("./results/points_created.txt", "w")

prime = HD::Ratio.from_s "1/1 2/1 3/2 2/3 16/9 32/27 8/3 2/1 3/1"

s = prime.to_s # converts a vector to a string for storage
n = NArray.to_na(s, Integer) # convert this string back into a vector (flat)
n.reshape(2,n.size/2) # reshapes the vector into its original form

# No alterations to the HDConfig
d_config = HD::HDConfig.new
d_config.prime_weights = [2,3,5,7,11]

# Reject all tuneable intervals that are past the prime limit
d_config.tuneable.reject! {|x| (x.distance(HD.r, d_config) ** -1) == 0}
d_config.tuneable.reject! {|x| x.to_f > 3.0}

max_hd = 7.129283016944966
max_ed = 3.0
m = -(0.1163 / 0.4041)

tuneable = HD::WeightedArray.new(*d_config.tuneable)
tuneable.weights.clear
tuneable.each { |x|
  hd = x.distance(HD.r, d_config) / max_hd
  ed = Math.log2(x.to_f) / max_ed
  # tuneable.weights << (m * (ed / hd)).abs ** 1.0
  tuneable.weights << hd
}
tuneable.weights[0] = 1.0

o = []
signs = [-1,1]

# There are 45,767,944,570,401 points, but we're only going through a few of them.
iterations = 10000
puts "== Status =="
# The collection of test points within the space are weighted toward the lower HD-values of intervals.
iterations.times do |i|
  o << Array[HD.r(1,1)]
  print "\r#{((i+1)*100.0)/iterations}% finished"
  8.times do |x|
    # weights = []
    # tuneable.each {|x| weights << (get_angle(NArray.to_na(o[-1].dup << x))[3] ** -2.0) }
    # tuneable.weights = weights
    possible = NArray[o[i][-1], (tuneable.choose ** signs.sample) * o[i][-1]]
    while !(all_tuneable?(possible, tuneable))
      possible = NArray[o[i][-1], (tuneable.choose ** signs.sample) * o[i][-1]]
      # puts "trying #{possible.to_a}"
    end
    o[i] << HD.r(possible[true,1][0], possible[true,1][1])
  end
  # print "\t\t#{NArray.to_na(o[-1]).to_a}"
end

puts "Writing to file..."
o.each do |x|
  output.puts x.join(" ")
end

output.close

puts "Took #{Time.now - t} seconds"