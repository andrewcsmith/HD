# Crystal Growth in Harmonic Space
# An example of a possible use of the HD module

require './hd.rb'

# These various config files will create different versions of the Crystal Growth 
# algorithm outlined in Marc Sabat's paper and tables extending James Tenney's work
ch = HD::Chord.new([HD::Ratio.new(1,1)])

# Projection Space:
config = HD::HDConfig.new([1,3,5,7,11,13,17,19,23])
# Harmonic Space (no octave)
config.prime_weights = [2,3,5,7,11,13,17,19,23]
# Harmonic Space (with octave)
# ch << HD::Ratio.new(2,1)

puts "Starting chord:"
ch.each {|x| puts x}
puts

config = HD::HDConfig.new([1,3,5])

# Wrapped to 1.0 <= pitch <= 2.0
config.options[:pc_only] = true

def add_me(ch, config)
  all_notes = []
  # Create a list of all possible candidates
  ch.candidates(config).each do |x| 
    #print "#{x}\t"
    m = HD::Chord.new([x])
    #print "#{(ch | m).hd_sum(config)}\n"
    # Had to .round(8) on the sum because of stupid rounding errors with sorting
    all_notes << [x, (ch | m).hd_sum(config).round(8), x.distance(HD::Ratio.new, config)]
  end
  
  # Sort them all
  all_notes.sort! do |x,y| 
    if x[1] == y[1]
      x[2] <=> y[2]
    else
      x[1] <=> y[1]
    end
  end
  # print "\nRatio\thd-sum\tdistance from 1/1"
  # all_notes.each {|x| printf("\n%s\t%0.3f\t%0.3f", x[0], x[1], x[2])}
  # Add the one with the least hd-sum and distance from 1/1 to the chord
  ch << all_notes[0][0]
end

12.times do |i|
  puts "Scale #{i+2}:"
  add_me(ch, config)
  ch.each {|x| puts x}
  puts
end