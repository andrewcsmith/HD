#! /usr/bin/ruby

#  ========== 
#  = HD     = 
#  ========== 
# A module for measuring harmonic distance

module HD
  require 'set'
  PRIMES = [2,3,5,7,11,13,17,19,23]
  
  # Holds the configuration parameters for the various HD measurement functions
  # Settings that are possible as of now: a custom list of prime number weights, 
  # and a custom filename from which to read in a list of tuneable intervals.
  class HDConfig
    attr_accessor :prime_weights, :tuneable
    def initialize(prime_weights = PRIMES.dup, tuneable = "tuneable.txt")
      warn "WARNING: Prime weights and list of primes are not the same size!" if prime_weights.size != PRIMES.size
      @prime_weights = prime_weights
      
      pattern = /(\d+)\/(\d+)/
      @tuneable = SortedSet.new
      # Reads in the entire list of tuneable intervals from a file
      File.open(tuneable, "r") do |intervals|
        intervals.readlines.each do |line|
          if (pattern =~ line) != nil
            full = Regexp.last_match
            @tuneable << HD::Ratio.new(full[1].to_i, full[2].to_i)
          end
        end
      end
    end
  end # HDConfig (class)
  
  # Ratio class, which defines a point in harmonic space.
  class Ratio
    include Enumerable
    
    attr_accessor :num, :den
    
    # Default value is 1/1. This make it easier to provide an origin of 1/1 for any distance function.
    def initialize(num = 1, den = 1)
      @num = num
      @den = den
    end
    
    # Predicate: returns whether or not the Ratio satisfies all conditions
    def satisfy?
      ratio = [@num, @den]
      ratio.each do |x|
        return false if (yield x) == false
      end
      true
    end
    
    # Necesssary to test for sets and subsets
    def eql? other
      @num == other.num && @den == other.den
    end
    
    # Defines the hash to properly test for equality
    def hash
      [@num, @den].hash
    end
    
    # Each iterator; required for Enumerable
    def each
      yield @num
      yield @den
    end
    
    # The normal map method returns an Array (we want a Ratio back)
    def map
      num = yield @num
      den = yield @den
      Ratio.new(num, den)
    end
    
    # Reduces the ratio and returns the value
    def reduce
      ratio = self.dup
      PRIMES.each {|z| ratio = ratio.map {|y| y /= z} while ratio.satisfy? {|y| y % z == 0}}
      ratio
    end
    
    # For each of the num and den, provides a list of exponents. Primes are only up through the size of PRIMES.
    def factors
      num = @num
      den = @den
      exponents = [num, den]
      exponents.map! do |y|
        PRIMES.map do |x|
          exp_count = 0
          while y % x == 0
            exp_count += 1
            y /= x
          end
          exp_count
        end
      end
      exponents
    end
    
    # Returns the harmonic distance from another point (or from the origin if no point is specified)
    # Defaults are distance from origin and default HDConfig object
    # an alternate origin may be specified, which would allow for distances from other points
    def distance(origin = HD::Ratio.new, config = HD::HDConfig.new)
      weights = config.prime_weights
      me = self.dup
      me.num *= origin.den
      me.den *= origin.num
      me = me.reduce
      factors = me.factors
      warn "Weights and factors are not the same size!" if factors[0].size != weights.size
      # Uses the "city blocks" metric
      city_blocks = 1
      for factor in factors
        weights.each_with_index do |w,i|
          city_blocks *= w ** factor[i]
        end
      end
      return Math::log2(city_blocks)
    end
    
    # Allows for an array of Ratio objects to be sorted according to size (scale order)
    def <=> other
      return self.num.to_f / self.den <=> other.num.to_f / other.den
    end
    
    def to_s
      return "#{@num} / #{@den}"
    end
  end # Ratio (Class)
  
  class Chord < SortedSet

    # Iterate through and create a set of pairs, not counting pairs of the same chord
    def pairs
      pairs = Set.new
      self.each do |x|
        self.each do |y|
          pairs << [x, y].sort
        end
      end
      pairs.reject! {|x| x[0] == x[1]}
      pairs
    end
    
    # sum of the combinatorial distance of all members of the chord.
    # the distance between each possible pair is computed, and that
    # amount is summed to compute the total distance
    def total_distance
      total = 0
      all_pairs = []
      self.pairs {|x,y| all_pairs << [x,y]}
      all_pairs.each {|x| total += x[0].distance(x[1])}
      total
    end
    
    def to_s
      str = ""
      self.each {|x| str << x}
    end
  end # Chord (Class)
end # HD (Module)

ratio = HD::Ratio.new(5,4)
origin = HD::Ratio.new(3,2)
other = HD::Ratio.new(7,4)
another = HD::Ratio.new(9,8)

puts "#{ratio} is %.3f from #{origin}" % ratio.distance(origin)
ch = HD::Chord.new [ratio, origin, other, another]

config = HD::HDConfig.new
tun = HD::HDConfig.new