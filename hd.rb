# =HD
# ==A module for measuring harmonic distance in just intonation
# 
# 
# 
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
  # Changing the constant is simple, but must be deliberate:
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
  # Settings that are possible as of now: a custom list of prime number
  # weights, and a custom filename from which to read in a list of tuneable
  # intervals.
  class HDConfig
    attr_accessor :pc_only, :prime_weights, :tuneable
    
    # Creates a new HDConfig object with the following default options:
    # * pc_only: false
    # * prime_weights: [2,3,5,7,11,13,17,19,23]
    # *  
    def initialize(options = { })
      @options = options
      @prime_weights =    options[:prime_weights]   || PRIMES.dup
      @pc_only =          options[:pc_only]         || false
      @tuneable_file =    options[:tuneable_file]   || "tuneable.txt"
      
      # Confirm that the :prime_weights item is an NArray
      @prime_weights = ::NArray.to_na(@prime_weights)
      
      if @prime_weights.size != PRIMES.size
        p = ::NArray.float(PRIMES.size)
        @prime_weights.to_a.each_with_index do |x, i|
          p[i] = x
        end
        @prime_weights = p
      end
      
      pattern = /(\d+)\/(\d+)/
      @tuneable = []
      # Reads in the entire list of tuneable intervals from a file
      File.open(@tuneable_file, "r") do |intervals|
        intervals.readlines.each do |line|
          if (pattern =~ line) != nil
            full = Regexp.last_match
            @tuneable << HD::Ratio[full[1].to_i, full[2].to_i]
          end
        end
      end
    end
    
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
    
    def reject_untuneable_intervals!
      self.tuneable.reject! {|x| (x.distance(HD.r, self) ** -1) == 0}
    end
    
    def reject_untuneable_intervals
      self.dup.reject_untuneable_intervals!
    end
    
  end # HDConfig (class)
  
  # Ratio class, which defines a point in harmonic space.
  # In the process of re-writing this so it is a 2D NVector
  class Ratio < NVector
    # attr_reader :num, :den
    include Enumerable
    require 'rational'
    
    # Default value is 1/1. This make it easier to provide an origin of 1/1 for any distance function.
    def initialize(*args)
      # if args.is_a? NArray && args.shape = [2]
        super(args[0], args[1])
      # else
      #   super[args]
      # end
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
    
    # Converts a string (separated by a tab, whitespace, or comma) to an array of HD::Ratio objects. 
    # Example:
    # HD::Ratio.from_s("1/1 4/3 16/7") # => Array[HD.r, HD.r(4,3), HD.r(16,7)]
    #
    # Can also be used to convert backward from a printed array of Ratios (i.e., to read in a file)
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
    
    # Generates a ratio from its constituent factors (expressed as a vector of prime exponents)
    def self.from_factors factors
      (factors.is_a? Array) ? factors = ::NArray.to_na(factors) : false
      f = PRIMES ** factors.abs
      # Assign the masked factors to the duplicated arrays
      Ratio[f[factors.ge(0.0)].prod, f[factors.le(0.0)].prod]
    end
    
    def dec
      return self[0].to_f / self[1]
    end
    
    def to_f
      return self.dec
    end
    
    def abs
      return Ratio[self[0].abs, self[1].abs]
    end
    
    def pc_space
      while self.dec >= 2.0
        self[1] *= 2
      end
      while self.dec < 1.0
        self[0] *= 2
      end
    end
    
    def * r
      if r.is_a? Ratio
        # Default response. All other ifs should point toward this.
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
        # Default response. All other ifs should point toward this.
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
      else
        # For some reason NVector doesn't respond to ** unless the other is 2,
        # so we have to call NArray's ** method
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
    
    # Defines the hash to properly test for equality
    def hash
      [self[0], self[1]].hash
    end
    
    def == r
      self.eql? r
    end
    
    # Each iterator; required for Enumerable
    def each
      yield self[0]
      yield self[1]
    end
    
    # The normal map method returns an Array (we want a Ratio back)
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
    
    # For each of the num and den, provides a list of exponents. Primes are only up through the size of PRIMES.
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
    
    # Returns the harmonic distance (as a "city block" measurement) between two points. If no second point is specified, then
    # it is assumed that we want the distance from a 1/1 origin.  
    # If either point in question lies outside of the harmonic
    # space, then the distance is _Infinity_. This comes into play in a number of ways, but the most common is as a filter
    # for the set of all tuneable intervals. Working in (for example) a 7-limit harmonic space would require that the
    # interval of 11/4 (while a tuneable interval) would not be eligible for use. Therefore, a distance of Infinity allows
    # this to be filtered out of the list of tuneable intervals. (See the method HDConfig#reject_untuneable_intervals! for
    # more information).
    def distance(origin = Ratio[1,1], config = HD::HDConfig.new)
      # Take weights from the config element passed in
      weights = config.prime_weights
      # Get the factors of the numerator and denominator of the interval from the point to the origin
      factors = (self.dup / origin).factors
      # In any reasonable sense, the weights array and factors array must be the same size
      if factors.size != weights.size
        warn "Weights and factors are not the same size!" 
        puts "Factors size: #{factors.size}, Weights size: #{weights.size}"
      end
      
      # If a factor's weight is 0 then it is outside of the harmonic space, and its distance is Infinity.
      if ((factors.ne 0) & (weights.ne 0)) != (factors.ne 0)
        return NMath.log2(0) * -1
      else # Calculation of the city block metric, using vectors instead of iteration
        wf = weights ** factors.abs
        NMath.log2((wf).abs[wf.ne 0.0].prod)
      end
    end
    
    # Allows for an array of Ratio objects to be sorted according to size (scale order)
    def <=> other
      if other.class == HD::Ratio
        return self[0].to_f / self[1] <=> other[0].to_f / other[1]
      elsif other.is_a? Numeric
        return self.to_f <=> other
      end
    end
    
    def < other
      if other.is_a? HD::Ratio
        return self[0].to_f / self[1] < other[0].to_f / other[1]
      elsif other.is_a? Numeric
        return self.to_f < other
      else
        raise Exception.new("WTF.")
      end
    end
    
    def > other
      if other.class == HD::Ratio
        return self[0].to_f / self[1] > other[0].to_f / other[1]
      end
    end
    
    def to_s
      return "#{self[0]}/#{self[1]}"
    end
  end # Ratio (Class)
  
  def self.narray_to_string(n)
    n.to_a.to_s
  end
  
  # The chord is essentially just a sorted set that translates some of the basic
  # functions so that they'll work with the Ratio objects. It also will calculate
  # the total distance between all possible points (combinatorial summation) and 
  # can return a set of all possible pairs.
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
    def hd_sum(config = HD::HDConfig.new)
      total = 0
      all_pairs = []
      self.pairs.each {|x,y| all_pairs << [x,y]}
      all_pairs.each {|x| total += x[0].distance(x[1], config)}
      total
    end
    
    # See "Crystal Growth in Harmonic Space," by James Tenney
    # as well as the tables and refinements suggested by
    # Marc Sabat & Wolfgang von Schweinitz (plainsound.org)
    #
    # Finds the point which is the least possible harmonic distance
    # from all other points, while not being a member of the chord
    # itself. Should have the smallest possible return of 
    # total_distance when added to the chord.
    #
    # 1. Look through all tuneable intervals for each member
    # 2. Add each one to the chord, and evaluate total_distance
    # 3. Pick the interval with the least total_distance
    def logical_origin(config = HDConfig.new)
      least_harmonic_distance = {:distance => nil, :ratio => nil}
      self.each do |m|
        config.tuneable.each do |i|
          if self.member? m * i
            next
          end
          if (m * i) > Ratio.new(9,2) || (m * i) < Ratio.new(4,9)
            next
          end
          c = self.dup
          c << m * i
          if (least_harmonic_distance[:ratio] == nil)
            least_harmonic_distance[:ratio] = m * i
            least_harmonic_distance[:distance] = c.hd_sum(config)
          elsif (least_harmonic_distance[:distance] > c.hd_sum(config))
            least_harmonic_distance[:ratio] = m * i
            least_harmonic_distance[:distance] = c.hd_sum(config)
          end
        end
      end
      least_harmonic_distance
    end
    
    # Returns an array of all possible candidates connected to the pitches
    # Optional argument pc_only allows for consideration of only pitch-class
    # projection space (where octave equivalency is respected)
    def candidates(config = HD::HDConfig.new)
      candidates = []
      self.each do |e|
        PRIMES.each do |p|
          # Add each connected element
          candidates << e * Ratio.new(p, 1)
          candidates << e * Ratio.new(1, p)
        end
      end
      # Filter everything for pitch-class space
      if config.pc_only
        candidates.each do |x|
          x = x.pc_space
        end
        candidates = candidates & candidates
      end
      candidates.reject! {|x| self.include? x}
      candidates
    end
    
    def to_s
      str = ""
      self.each {|x| str << x}
    end
  end # Chord (Class)
  
  class WeightedArray < Array
    def initialize(*x)
      if x
        super(x)
      else
        super
      end
      @weights = Array.new(self.size, 1)
    end
  
    def choose
      normalized = []
      # Normalize (divide each weight by the sum of all weights)
      sum = 0.0
      @weights.each {|x| sum += x}
      if sum == 0.0
        raise "WTF SUM IS ZERO"
      end
      normalized = @weights.map {|x| x /= sum }
      normalized.each_with_index {|x,i| x += normalized[i-1] unless i == 0}      
      # Each item should equal itself plus the previous item      
      ranking = Array.new(normalized.size)
      normalized.each_index do |i| 
        if i == 0
          ranking[i] = normalized[i]
        else
          ranking[i] = ranking[i-1] + normalized[i]
        end
      end
      begin
        r = rand
        chosen = 0
        
        while r >= ranking[chosen]
          chosen += 1
        end
      rescue ArgumentError => er
        print "#{er.message}\n#{r}\t#{ranking}"
      end
      
      return self[chosen]
    end
  
    # Sets the new weighting
    def weights=(input_weights)
      if !(input_weights.instance_of? Array)
        return nil
      end
      input_weights.map! {|x| x.to_f}
      @weights = input_weights if input_weights.size == self.size
    end
  
    def weights
      return @weights
    end
  end
  
  # A series of functions for choosing new pitches.
  
  #
  # Select: Provide this thing with a base ratio and a config file (with prime weights 
  # & tuneable intervals) and it'll choose a new pitch based on that prime number weighting.
  # Supremely useful for finding the next interval to use based on harmonic distance, without
  # being entirely deterministic. Essentially creates a distribution of probabilities to shoot for
  # 
  # Ideas: r could be the current origin at all times. So that would create a certain cloud
  # around a particular pitch. When that cloud encroaches on another origin, the cloud
  # may change its origin. That's left for a different controller module.
  #
  
  def self.select(r = Ratio.new, config = HDConfig.new)
    intervals = config.tuneable.map {|x| r * x}
    intervals = WeightedArray.new(*intervals)
    puts "#{intervals}"
    intervals.weights = intervals.map do |x| 
      if x.distance == 0.0
        0.0
      else
        1.0 / x.distance
      end
    end
    puts "#{intervals.weights}"
    intervals.choose
  end
  
  #
  # Shorthand: Outside of the class, HD.r(n, m) is short for HD::Ratio.new(n, m)
  #
  class_eval(<<-EOS, __FILE__, __LINE__)
    def self.r(n = 1, m = 1)
      Ratio[n, m]
    end
  EOS
  
end # HD (Module)