module HD
  # The chord is essentially just a sorted set that translates some of the
  # basic functions so that they'll work with the Ratio objects. It also will
  # calculate the total distance between all possible points (combinatorial
  # summation) and can return a set of all possible pairs.
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

  # Select: Provide this thing with a base ratio and a config file (with prime
  # weights & tuneable intervals) and it'll choose a new pitch based on that
  # prime number weighting. Supremely useful for finding the next interval to
  # use based on harmonic distance, without being entirely deterministic.
  # Essentially creates a distribution of probabilities to shoot for
  # 
  # Ideas: r could be the current origin at all times. So that would create a
  # certain cloud around a particular pitch. When that cloud encroaches on
  # another origin, the cloud may change its origin. That's left for a
  # different controller module.
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
end