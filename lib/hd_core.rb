# =HD
# ==A module for measuring harmonic distance in just intonation
# 
# 
# This module takes much of its inspiration from two sources: 
# 
# The more general theoretical source is James Tenney's measurement of
# "Harmonic Distance", both in the way that harmonic distance is measured
# across a single interval and in the features given that compute the HD-sum
# of a given pitch aggregate.
# 
# The other theoretical source, specific to just intonation performance, is
# the range of "tuneable intervals" discussed by Marc Sabat and Wolfgang von
# Schweinitz. The "tuneable intervals" are a list of intervals that can be
# tuned in a single step by ear, with reasonable accuracy.
# 
# (In an interesting parallel between the work of Tenney and Sabat, this list
# of intervals does not include anything smaller than 8/7 or anything too
# close to a 2/1 octave. This parallels Tenney's recognition that lower-limit
# prime ratios create a larger bandwidth of tolerance in which the ear
# perceives nearby complex ratios as "out of tune" simpler ratios.)
# 

module HD
  require 'set'
  require 'narray'
  
  # A list of the prime numbers in use for a particular musical application.
  # In this case, the primes stop at 23 as that is the upper limit for many
  # musical compositions, and using a smaller list of primes makes processing
  # easier (since the list is iterated over often).
  # 
  # Changing the constant is simple:
  # 
  #   module HD
  #     PRIMES = ::NArray[...]
  #   end
  # 
  # This way, it cannot be "accidentally" changed.
  PRIMES = ::NArray[2,3,5,7,11,13,17,19,23].to_f
  
  # This addition to the NArray
  class NArray
    def distance(origin = nil, config = HD::HDConfig.new)
      dist_vectors = NArray.object(self.total)
      for i in 0...self.total
        dist_vectors[i] = self[i].distance(origin[i], config)
      end
      dist_vectors
    end
  end
  
  # Holds the configuration parameters for the various HD measurement
  # functions.
  # 
  # Options:
  # 
  # [+:prime_weights+]  How much each "city block" is weighted in the particular metric space.
  # [+:pc_only+]        A convenient way of setting the weighting of prime 2 to 1
  # [+:tuneable_file+]  Location of a file with the list of tuneable intervals
  # 
  class HDConfig
    attr_accessor :pc_only, :tuneable
		attr_reader :prime_weights
    
    # Creates a new HDConfig object with the following default options:
    # * pc_only: false
    # * prime_weights: [2,3,5,7,11,13,17,19,23]
    # * tuneable: List from Marc Sabat's "Analysis of Tuneable Intervals on Violin and Cello"
    def initialize(options = { })
			# Assumes that there is a file called "tuneable.txt" in a "data" subdirectory of
			# the superdirectory of this script
			default_tuneable_file = File.open(File.dirname(File.expand_path(__FILE__)) + "/../data/tuneable.txt")
      @options = options
      self.prime_weights =	options[:prime_weights]   || PRIMES.dup
      @pc_only =          	options[:pc_only]         || false
      @tuneable_file =    	options[:tuneable_file]   || default_tuneable_file
      
      pattern = /(\d+)\/(\d+)/
      # Reads in the entire list of tuneable intervals from a file
      File.open(@tuneable_file) do |intervals|
        @tuneable = intervals.readlines.inject([]) do |tuneable, line|
					# If the line doesn't contain a matching pattern, it skips over that line by
					# returning the unaltered memo.
					pattern =~ line ? (tuneable << HD::Ratio[$1.to_i, $2.to_i]) : tuneable
        end
      end
    end
    
    # Setter for [+:prime_weights+]. Any unspecified weights past the highest value
    # in the setter array are set to 0.
		def prime_weights=(new_weights)
      if new_weights.size != PRIMES.size
        PRIMES.size.times do |i|
          if new_weights[i] == nil
            new_weights[i] = 0.0
          end
        end
      end
      @prime_weights = ::NArray.to_na(new_weights)
    end
    
    # Rejects all intervals that are outside of the space of tuneable intervals
    def reject_untuneable_intervals!
      self.tuneable.reject! {|x| (x.distance(HD.r, self) ** -1) == 0}
    end
    
    def reject_untuneable_intervals
      self.dup.reject_untuneable_intervals!
    end
    
  end # HDConfig (class)
  
  # Ratio class, which defines a point in harmonic space. A Ratio is a
  # 2-dimensional NVector where the first dimension is numerator and second is
  # denominator. Create a new Ratio (in the general namespace) with: 
  # 
  #   HD::Ratio[x, y]
  # 
  # or with the shortcut:
  # 
  #   HD.r(x, y)
  # 
  # A newly created Ratio is automatically reduced to its lowest common terms.
  # 
  # The Rational class has not been used as a superclass, because the
  # succession of NVectors translates very well into a 3-dimensional NArray
  # when operating on a vector of Ratio objects. This increases compatability
  # with the Morphological Metrics library.
  class Ratio < NVector
    include Enumerable
		include Comparable
    
    # Default value is 1/1. This makes it easier to provide an origin of 1/1
    # for any distance function.
    def initialize(*args)
      super(args[0], args[1])
    end
    
    def self.[] *args
      # Create an NVector with type int and length of 2
      # (note: does **not** create the ratio 3/2)
      r = Ratio.new(3,2)
      
      r[0] = args[0]
      r[1] = args[1]
      !r[1] ? r[1] = 1 : false
      r.reduce
    end
    
    # Reduces the ratio and returns the value
    def reduce
      r = self.dup
      # Save the factors (only perform this operation once)
      factors = r.factors
      # Returns an array of all-positive exponents
      f = PRIMES ** factors.abs
      # Assign the masked factors to the duplicated arrays
      r[0] = (f[factors.gt(0.0)].prod.is_a? Numeric) ? f[factors.gt(0.0)].prod : 1
      r[1] = (f[factors.lt(0.0)].prod.is_a? Numeric) ? f[factors.lt(0.0)].prod : 1
      r
    end
    
    # Converts a string (separated by a tab, whitespace, or comma) to an array
    # of HD::Ratio objects. Example: 
    # 
    #   HD::Ratio.from_s("1/1 4/3 16/7") 
    #   # => Array[HD.r, HD.r(4,3), HD.r(16,7)]
    #
    # Can also be used to convert backward from a printed array of Ratios
    # (i.e., to read in a file)
    def self.from_s s
      ratios = s.scan(/(\d+)\/(\d+)/)
      ratios.map! {|x| Ratio[x[0].to_i, x[1].to_i] }
      ::NArray.to_na(ratios)
    end
    
    def self.from_a a
      ratios = []
      a.each {|x| ratios << HD.r(x[0], x[1])}
      ::NArray.to_na(ratios)
    end
    
    def self.from_na na
      if na.shape[0] != 2
        raise "First dimension of HD::Ratio#from_na must be 2"
      end
      r = Ratio.new(3,2)
      r[0] = na[0]
      r[1] = na[1]
      r.reduce
    end
    
    # For each of the num and den, provides a list of exponents. Primes are
    # only up through the size of PRIMES. This is mostly for the sake of
    # efficiency.
    def factors
      exponents = ::NArray.int(PRIMES.size, 2)
      self.each_with_index do |y, i|
        exponents[true,i] = ::NArray.to_na(PRIMES.to_a.map do |x|
          exp_count = 0
          while y % x == 0
            exp_count += 1
            y /= x
          end
          exp_count
        end)
      end
      # Will be an NArray of exponents (negative numbers are denominators)
      exponents[true,0] - exponents[true,1]
    end
    
    # Generates a ratio from its constituent factors (expressed as a vector of
    # prime exponents)
    def self.from_factors factors
      (factors.is_a? Array) ? factors = ::NArray.to_na(factors) : false
      f = PRIMES ** factors.abs
      # Assign the masked factors to the duplicated arrays
      Ratio[f[factors.ge(0.0)].prod, f[factors.le(0.0)].prod]
    end
    
    def dec
      self[0].to_f / self[1]
    end
    
    def to_f
      self.dec
    end
    
    def abs
      Ratio[self[0].abs, self[1].abs]
    end
    
    def pc_space
      while self.dec >= 2.0
        self[1] *= 2
      end
      while self.dec < 1.0
        self[0] *= 2
      end
    end
    
    # Multiplication and division are done by factoring the consituent
    # dimensions of the Ratio object and adding or subtracting the exponents
    # of the prime numbers. Because of this, any Ratio object that uses prime
    # numbers not included in the PRIMES variable may lead to bugs. 
    def * r
      if r.is_a? Ratio
        # Default response. All elsifs should point toward this.
        Ratio.from_factors(self.factors + r.factors)
      elsif r.is_a? Numeric
        self * Ratio[r, 1]
      elsif r.is_a? NArray
        self * Ratio[*r].factors
      else
        raise ArgumentError.new("Supplied class #{r.class} to HD::Ratio.*")
      end
    end
    
    def / r
      if r.is_a? Ratio
        # Default response. All elsifs should point toward this.
        Ratio.from_factors(self.factors - r.factors)
      elsif r.is_a? Numeric
        self / Ratio[1, r]
      else
        raise ArgumentError.new("Supplied class #{r.class} to HD::Ratio./")
      end
    end
    
    def ** r
      if r == 2
        super
      elsif r == -1
        Ratio[self[1], self[0]]
      else
        # NVector treats ** as A * A (produces a single digit), instead of the
        # element-wise operation of ** that NArray allows. Have to call
        # NArray's ** method for this.
        ::NArray.instance_method(:**).bind(self).call(r)
      end
    end
    
    def - r
      if r.is_a? Ratio
        Ratio[self[0] * r[1] - self[1] * r[0], r[1] * self[1]]
      elsif r.is_a? Numeric
        self.-(Ratio[r, 1])
      else
        raise Exception.new("Supplied class #{r.class} to HD::Ratio.-")
      end
    end
    
    def + r
      if r.is_a? HD::Ratio
        Ratio[self[0] * r[1] + self[1] * r[0], self[1] * r[1]]
      elsif r.is_a? Numeric
        Ratio[self[0] + r * self[1], self[1]]
      else
        raise ArgumentError.new("Supplied class #{r.class} to HD::Ratio.+")
      end
    end
    
    def coerce(other)
      return self, other
    end
    
    # Defines the hash to properly test for equality.
    def hash
      [self[0], self[1]].hash
    end
    
    # Necesssary to test for sets and subsets
    def eql? r
      if r.is_a? Ratio
        return (self[0] == r[0] && self[1] == r[1])
      elsif r.is_a? Fixnum
        return (self.to_f == r)
      else
        raise TypeError.new("Tried to compare a #{r.class} to an HD::Ratio")
      end
    end
    
    # Alias for :eql?
    def == r
      self.eql? r
    end
    
    # Each iterator; required for Enumerable
    def each
      yield self[0]
      yield self[1]
    end
    
    # The normal map method returns an Array, but we want a Ratio back. So
    # this is a slightly different method.
    def map
      r = self.dup
      begin
        r[0] = yield r[0]
        r[1] = yield r[1]
      rescue TypeError => e
        warn "the block associated with #map returned nil; aborting map function"
        puts e.backtrace
      end
      r
    end
    
    # Returns the cents-distance of an interval
    def cents(origin = Ratio[1,1])
      n = self.to_f
      m = origin.to_f
      Math.log2(n / m) * 1200.0
    end
    
    # Returns the harmonic distance (as a "city block" measurement) between
    # two points. If no second point is specified, then it is assumed that we
    # want the distance from a 1/1 origin.  If either point in question lies
    # outside of the harmonic space, then the distance is <tt>Infinity</tt>. This
    # comes into play in a number of ways, but the most common is as a filter
    # for the set of all tuneable intervals. Working in (for example) a
    # 7-limit harmonic space would require that the interval of 11/4 (while a
    # tuneable interval) would not be eligible for use. Therefore, a distance
    # of Infinity allows this to be filtered out of the list of tuneable
    # intervals. (See the method <tt>HDConfig#reject_untuneable_intervals!</tt> for
    # more information).
    def distance(origin = Ratio[1,1], config = HD::HDConfig.new)
      # Take weights from the config argument
      weights = config.prime_weights
      # Get the factors of the interval between self and the origin arg
      factors = (self.dup / origin).factors
      # The weights array and factors array must be the same size, because
      # otherwise there's the potential of missing weights, or untraceable
      # bugs.
      if factors.size != weights.size
        warn "Weights and factors are not the same size!" 
        puts "Factors size: #{factors.size}, Weights size: #{weights.size}"
      end
      
      # If the Ratio in question contains a prime number factor whose weight
      # has been set to 0, then it is outside of the harmonic space, and its
      # distance is Infinity. To say that a certain prime factor "doesn't
      # matter" (e.g., "octave equivalency"), set that factor's weight to 1.
      if ((factors.ne 0) & (weights.ne 0)) != (factors.ne 0)
        return NMath.log2(0) * -1
      else 
        # Calculation of the city block metric, using vectors instead of
        # iteration.
        wf = weights ** factors.abs
        NMath.log2((wf).abs[wf.ne 0.0].prod)
      end
    end
    
    # Allows for an array of Ratio objects to be sorted according to size
    # (scale order)
    def <=> other
      if other.class == HD::Ratio
        return self[0].to_f / self[1] <=> other[0].to_f / other[1]
      elsif other.is_a? Numeric
        return self.to_f <=> other
      end
    end
    
    def to_s
      return "#{self[0]}/#{self[1]}"
    end
  end # Ratio (Class)
  
  # Convenience method for determining whether or not all the intervals are
  # tuneable Provide it with a point to test and an array of tuneable
  # intervals (HD::Ratio objects)
  def self.all_tuneable?(point, tuneable, range = [HD.r(2,3), HD.r(16,3)])
    for i in 0...point.shape[1]
      # Using the same variable name to note intervals that are out of range
      # (Default range settings are for the violin)
      m = Ratio[*point[true,i]]
      (m < range[0] || m > range[1]) ? (return false) : 
      # If it's the first interval, we don't care about tuneability
      i == 0 ? next : n = Ratio[*point[true,i-1]]
      # This is the actual tuneability part
      # interval = m / n
      !((tuneable.include? m / n) || (tuneable.include? n / m)) ? (return false) : next
    end
    true
  end
  
  # Changes the inner-interval of a vector
  def self.change_inner_interval(v, index, interval)
    vector_delta = MM.vector_delta(v, 1, MM::DELTA_FUNCTIONS[:hd_ratio], MM::INTERVAL_FUNCTIONS[:pairs])
    vector_delta[true,index] = interval
    new_vector = MM.vector_from_differential(vector_delta)
    return new_vector
  end
  
  # ==Informational methods:
  # 
  # Returns a vector of precise frequencies. Useful for annotating scores for
  # rehearsal, or for making SuperCollider mockups.
  def self.get_frequencies_from_vector(v, base = 440.0)
    a = NArray.float(3,v.shape[1])
    a[0..1,true] = v
    a[2,true] = a[0,true] / a[1,true]
    
    b = a[2,true] * base
    b
  end
  
  # Returns a two-dimensional vector:
  # dim-1: The cents deviations from 1/1 (tuning pitch)
  # dim-2: Cents deviations from the nearest 12TET pitch
  def self.get_cents_from_vector(v)
    if !v.is_a? NArray
      v = NArray.to_na(v)
    end
    a = NArray.float(3,v.shape[1])
    a[0..1,true] = v
    a[2,true] = a[0,true] / a[1,true]
    
    # b is a vector of the cents deviations from 1/1, and then the deviations from the nearest et pitch
    b = NArray.float(2,a.shape[1])
    b[0,true] = NMath.log2(a[2,true]) * 1200.0
    
    b[1,true] = b[0,true].collect {|x| (x.round(-2) - x).round(1) * -1}
    b
  end
  
  def self.narray_to_string(n)
    n.to_a.to_s
  end
  
  # Outside of the class, HD.r(n, m) is short for HD::Ratio[n, m]
  class_eval(<<-EOS, __FILE__, __LINE__)
    def self.r(n = 1, m = 1)
      Ratio[n, m]
    end
  EOS
  
end # HD (Module)