# This is an inter_delta function to compare the harmonic distance between corresponding elements of a vector
# If used as an intra_delta function for linear magnitudes

# The only issue with MM compatability is that the configuration must be an outside variable, and not part of the proc, or it must be defined with the definition of the proc. In other words, it might make more sense to define a function that returns a proc based on the config that is passed into it. This way, a proc could then be passed to the MM functions and remain effective (linked to an outside HDConfig)

# In combinatorial metrics, the intra_delta acts upon each of the possible pair combinations. By contrast, a linear metric is passed two NArrays filled with objects that need to be acted upon, in this case HD::Ratio objects, of [0...a.total-1] and [1...a.total], so that each successive pair is operated upon.

# Refactored into one Proc: this harmonic_distance_delta will respond correctly to both an HD::Ratio (as in combinatorial metrics) and an NArray (as in linear metrics). 

# Fixing the NArray to_f method
class NArray
  def to_f
    NArray[*self.collect {|x| x.to_f}]
  end
end

module MM
  def self.get_harmonic_distance_delta(config = HD::HDConfig.new)  
    ->(a, b) {
      if a.is_a? HD::Ratio
        return a.distance(b, config)
      elsif a.is_a? Array # If it's an array, we'll need to make it an NArray first
        a = NArray.to_na(a)
        b = NArray.to_na(b)
      elsif a.is_a? NArray # If the first argument is an NArray
        true # No prep needed
      else
        raise Exception.new("harmonic_distance_delta only works with NArray or HD::Ratio\nYou passed it an #{a.class}")
      end
      # If the array is one-dimensional it's probably a single HD::Ratio as a 2D vector
      # Return the single float distance, same as calling a.distance(b)
      a.shape == [2] ? (return HD::Ratio[a[0],a[1]].distance(HD::Ratio[b[0],b[1]],config).abs) : false
      # If it's a vector, then create a vector to hold all the inter-vector distances
      dist_vectors = NArray.float(a.shape[1])
      for i in 0...dist_vectors.size
        dist_vectors[i] = HD::Ratio[a[0,i],a[1,i]].distance(HD::Ratio[b[0,i],b[1,i]], config).abs
      end
      return dist_vectors
    }
  end
  
  MM::INTERVAL_FUNCTIONS[:pairs] = lambda do |m|
    m[true,1...m.shape[1]]
  end
  
  # Convenience method for determining whether or not all the intervals are tuneable
  # Provide it with a point to test and an array of tuneable intervals (HD::Ratio objects)
  def self.all_tuneable?(point, tuneable, range = [HD.r(2,3), HD.r(16,3)])
    for i in 0...point.shape[1]
      # Using the same variable name to note intervals that are out of range
      # (Default range settings are for the violin)
      m = HD::Ratio[*point[true,i]]
      (m < range[0] || m > range[1]) ? (return false) : 
      # If it's the first interval, we don't care about tuneability
      i == 0 ? next : n = HD::Ratio[*point[true,i-1]]
      # This is the actual tuneability part
      interval = m / n
      !((tuneable.include? interval) || (tuneable.include? (interval ** -1))) ? (return false) : next
    end
    true
  end
  
  @get_harmonic_search = ->(opts) {
    climb_func        = opts[:climb_func]
    start_vector      = opts[:start_vector]
    epsilon           = opts[:epsilon]          || 0.01
    min_step_size     = opts[:min_step_size]    || 0.005
    start_step_size   = opts[:start_step_size]  || 1.0
    max_iterations    = opts[:max_iterations]   || 1000
    return_full_path  = opts[:return_full_path] || false
    
    
  }

    ##
    # The goal is to write a greedy A * search algorithm
    #
    # Takes a hash with the following keys:
    #
    # [+:climb_func+] A proc. This is the function the algorithm will attempt 
    #                 to minimize.
    # [+:start_vector+] The starting point of the search.
    # [+:epsilon+] Anything point below this distance will be considered a 
    #              successful search result. Default: 0.01
    # [+:min_step_size+] The minimum step size the search algorithm will use. Default: 0.1
    # [+:start_step_size+] The starting step size. Default: 1.0
    # [+:max_iterations+] The number of steps to take before giving up.
    # [+:return_full_path+] If true, this will return every step in the search.
    # [+:step_size_subtract+] If set to a value, every time the algorithm needs
    #                         to decrease the step size, it will decrement it
    #                         by this value. Otherwise it will divide it by 2.0.
    #
  @@get_hd_search = ->(opts) {
    climb_func         = opts[:climb_func]
    start_vector       = opts[:start_vector]
    epsilon            = opts[:epsilon]            || 0.01
    min_step_size      = opts[:min_step_size]      || 0.005
    start_step_size    = opts[:start_step_size]    || 1.0
    max_iterations     = opts[:max_iterations]     || 1000
    return_full_path   = opts[:return_full_path]   || false
    step_size_subtract = opts[:step_size_subtract]
    step_size_modifier = opts[:step_size_modifier] || :*.to_proc
    new_point_modifier = opts[:new_point_modifier] || :*.to_proc
    # Added this so that we could get a custom list of tuneable intervals & prime_weights in there
    hd_config          = opts[:hd_config]          || HD::HDConfig.new
    check_tuneable_intervals = opts[:check_tuneable] || false
    config              = opts[:config]              || HD::HDConfig.new
    banned              = opts[:banned]             || nil

    # Load the list of tuneable intervals from the options
    tuneable = hd_config.tuneable
    # Sorts them so that the intervals which cause the greatest leaps in magnitude of harmonic distance will be used first
    tuneable.sort_by! {|x| x.distance(HD.r, hd_config)}
    # Reject anything with a distance of Infinity (out of the prime limit)
    tuneable.reject! {|x| (x.distance(HD.r, hd_config) ** -1) == 0}
    
    start_distance = climb_func.call(start_vector)
    # Length of the vector is the number of dimensions
    dimensions = start_vector.shape[1]
    step_size = start_step_size
    # Either divide, stay the same, or multiply
    candidates = [-1, 0, 1]
    # Make an array of all possible combinations over the length of the vector
    all_candidates = candidates.repeated_combination(start_vector.shape[1]).to_a
    all_candidates.reject! {|x| x.all? {|y| y == x[0]}}
    all_candidates.map! {|x| NArray.to_na(x)}
    
    results = []
    
    current_point = [start_vector.dup, start_distance]
    path = [current_point]
    
    log = File.new("results/log #{Time.now}.txt", "w")
    
    # Holds an array of all intervals that are the "wrong way" to go. There is the assumption that if a point leads to a dead-end at one time, it will always lead to a dead-end and that point should always be rejected.
    if banned
      wrong_way = banned
    else
      wrong_way = []
    end
    # dead_ends is a catalog of every dead end that has been found by the search function. The keys are all points, while the values are tuneable intervals. If a tuneable interval returns no possible tuneable points (not equal to the current point) than it is deemed a dead end, and added to that point's list of dead ends in the value array.
    dead_ends = {}
    climb_scores = {}
    
    max_iterations.times do |iteration|
      if wrong_way.include? start_vector
        puts "Start vector is a dead end"
        puts "Aborting climb at iteration #{iteration} :("
        break
      end
      # Sorts the list of tuneable intervals by whether they can possibly bring the vector closer
      # The current point will be multiplied by the tuneable interval, across the vector
      
      puts "- Iteration #{iteration}\t\tPath: #{path.size} points"
      current_point_cache = current_point.dup
      
      # Calculate and cache the climb_score of the current_point
      !climb_scores[current_point[0]] ? climb_scores[current_point[0]] = climb_func.call(current_point[0]).to_f : false
      current_result = climb_scores[current_point[0]]
      
      #warn "Current Result: #{current_result}\nCurrent Path: #{path[-1]}"
      
      puts "Current point is #{current_point[0].to_a} with a distance of #{"%0.3f" % current_result}"
      log.puts "Current path is #{path.to_a}"
      # Initialize a dead ends hash entry for the current point if it does not already have one
      dead_ends[current_point[0]] == nil ? dead_ends[current_point[0]] = [] : false
      # Generate a collection of test points with scores: [point, score]
      test_points = []
      # Sort the list of tuneable intervals by the mean hd-sum of all possible tuneable combinations operating on the current vector
      scores = []
      # print "all candidates: #{all_candidates}"
      # highest_g_cost = Math.sqrt(all_candidates[0].total)
      for i in tuneable
        interval_score = 0.0
        interval_count = 0
        scores_cache = scores.dup
        # If the current tuneable interval is a dead end, skip it and try the next one
        (dead_ends[current_point[0]].include? i) ? next : false
        for j in all_candidates
          possible_point = current_point[0] * (i ** j)
          # Normalize the point
          (possible_point[0] != HD.r) ? possible_point *= (possible_point[0] ** -1) : false
          # If the possible point is the wrong way, skip it
          !(wrong_way.include? possible_point) ? true : next
          # If the point is not tuneable, skip it, and add it to the wrong_way array to speed up future computations
          all_tuneable?(possible_point, tuneable) ? true : (wrong_way << possible_point; next)
          # Makes a list of what will move get us the closest
          # In the F = G + H of the A * algorithm, this is the H
          # We cache the H distance for all the points so that we don't have to re-calculate it later
          !climb_scores[possible_point] ? climb_scores[possible_point] = climb_func.call(possible_point).to_f : false
          h = climb_scores[possible_point]
          # This g function wants to minimize the euclidian distance travelled between steps
          # g = MM.dist_ulm(possible_point, current_point[0], MM::DistConfig.new({:scale => :relative})).to_f
          # The scores are [point, h, g] where h is the heuristic measure of how far we are from the goal and g is the distance we've travelled so far
          scores << [possible_point, h.to_f]
        end
        # if none of the candidates were cool, then add this interval to the dead ends
        scores == scores_cache ? dead_ends[current_point[0]] << i : false
      end
      
      scores.reject! {|x| x[0] == current_point[0]}
      
      # Check to see if the current vector is a dead end
      if scores.all? {|x| x == nil}
        if path.size > 0
          puts "This vector is a dead end"
          wrong_way << path.pop[0]
          current_point = path[-1]
          next
        else
          puts "Start vector is a dead end"
          puts "Aborting climb at iteration #{iteration} :("
          break
        end
      end
      
      # We sort by h + g, to pick the point that gets us closest
      # scores.sort_by! {|x| x[1] + (x[2] / (path.size + 1.0))}
      scores.sort_by! {|x| x[1]}
      scores.reject! {|x| x[0] == current_point}
      s_cache = nil
      # Reject duplicate values
      scores.reject! {|x| (x[0] == s_cache) ? (s_cache = x[0]; true) : (s_cache = x[0]; false)}      
      
      winner = nil
      for s in scores
        if climb_scores[s[0]] < current_result
          winner = s
          break
        end
      end
      
      if winner == nil
        if path.size > 0
          puts "Can't move any closer from the current vector"
          wrong_way << path.pop[0]
          current_point = path[-1]
          next
        else
          puts "all possible movements just make us go further away"
          puts "Aborting climb at iteration #{iteration} :("
          break
        end
      end
        
      current_point = winner
      # The path is made up of two entries: [point, distance via path to the current point]
      # path << [current_point.dup, (MM.dist_ulm(current_point, path[-1]) + path[-1][1]).to_f]
      path << current_point
      
      # Test score is h
      test_score = climb_scores[current_point[0]]
      if test_score < (0 + epsilon) && test_score > (0 - epsilon)
        puts "Success at iteration #{iteration}"
        break
        # The following is what you do when you want a bunch of points the same distance away (a SPHERE)
        # Comment out "break" above
        wrong_way << path.pop[0]
        results << wrong_way[-1].dup
        current_point = path[-1]
        next
      end
      
      if current_point[0] == current_point_cache[0]
        if path.size > 0
          wrong_way << path.pop[0]
          current_point = path[-1]
          puts "This vector got us nowhere"
        else
          puts "Aborting climb at iteration #{iteration} :("
          break
        end
      end
      
    end
    log.close
    return path if return_full_path
    current_point
  }

  #
  # Make each distance metric lambda readable from the outside, i.e.
  # attr_reader behavior, and also provide sugar for avoiding .call
  # (use dist_#{metric}() instead).
  #
  [:get_hd_search].each do |sym|
    class_eval(<<-EOS, __FILE__, __LINE__)
      unless defined? @@#{sym}
        @@#{sym} = nil
      end

      def self.#{sym}
        @@#{sym}
      end

      def #{sym}
        @@#{sym}
      end
      
      def self.dist_#{sym}(*args)
        @@#{sym}.call(*args)
      end
    EOS
  end
  
  # Deprecated: Use get_harmonic_distance_delta
  # Returns a Proc for harmonic distance, but with a permanent HDConfig Object attached
  def self.get_harmonic_distance_delta_single(config = HD::HDConfig.new)
    ->(a, b) { 
      warn "get_harmonic_distance_delta_single deprecated. Use get_harmonic_distance_delta."
      a.distance(b, config) }
  end
end