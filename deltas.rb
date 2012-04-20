# This is an inter_delta function to compare the harmonic distance between corresponding elements of a vector
# If used as an intra_delta function for linear magnitudes

# The only issue with MM compatability is that the configuration must be an outside variable, and not part of the proc, or it must be defined with the definition of the proc. In other words, it might make more sense to define a function that returns a proc based on the config that is passed into it. This way, a proc could then be passed to the MM functions and remain effective (linked to an outside HDConfig)

# In combinatorial metrics, the intra_delta acts upon each of the possible pair combinations. By contrast, a linear metric is passed two NArrays filled with objects that need to be acted upon, in this case HD::Ratio objects, of [0...a.total-1] and [1...a.total], so that each successive pair is operated upon.

# Refactored into one Proc: this harmonic_distance_delta will respond correctly to both an HD::Ratio (as in combinatorial metrics) and an NArray (as in linear metrics). 
module MM
  require 'thread'
  
  def self.get_harmonic_distance_delta(config = HD::HDConfig.new)  
    ->(a, b) {
      if a.is_a? HD::Ratio
        return a.distance(b, config)
      elsif (a.is_a? NArray) && (a[0].is_a? HD::Ratio) # If the first argument is an NArray of Ratios
        dist_vectors = NArray.object(a.total)
        for i in 0...a.total
          dist_vectors[i] = (a[i].distance(b[i], config)).abs
        end
        return dist_vectors
      else
        raise Exception.new("harmonic_distance_delta only works with NArray or HD::Ratio")
      end
    }
  end
  
  # Convenience method for determining whether or not all the intervals are tuneable
  # Provide it with a point to test and an array of tuneable intervals (HD::Ratio objects)
  def self.all_tuneable?(point, tuneable)
    for i in 0...point.total
      # Using the same variable name to note intervals that are out of range for the violin (with D = 1/1)
      (point[i] < HD.r(2,3) || point[i] > HD.r(16,3)) ? (return false) : 
      
      # If it's the first interval, we don't care about tuneability
      i == 0 ? next :
      # This is the actual tuneability part
      interval = point[i] / point[i-1]
      !((tuneable.include? interval) || (tuneable.include? (interval ** -1))) ? (return false) : next
    end
    true
  end

    ##
    # :singleton-method: hill_climb_stochastic_hd
    #
    # A stochastic hill climbing algorithm. Probably a bad one.
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

    # Load the list of tuneable intervals from the options
    tuneable = hd_config.tuneable
    # Sorts them so that the intervals which cause the greatest leaps in magnitude of harmonic distance will be used first
    tuneable.sort_by! {|x| x.distance(HD.r, hd_config)}
    # Reject anything with a distance of Infinity (out of the prime limit)
    tuneable.reject! {|x| (x.distance(HD.r, hd_config) ** -1) == 0}
    
    start_distance = climb_func.call(start_vector)
    # start_step_size *= start_distance
    
    # Length of the vector is the number of dimensions
    dimensions = start_vector.total

    step_size = start_step_size
    
    times_with_same_vector = 0
    
    # Either divide, stay the same, or multiply
    candidates = [-1, 0, 1]
    # Make an array of all possible combinations over the length of the vector
    all_candidates = candidates.repeated_combination(start_vector.total).to_a
    all_candidates.reject! {|x| x.all? {|y| candidates.include? y}}
    current_point = start_vector.dup
    path = [start_vector]
    
    # Holds an array of all intervals that are the "wrong way" to go. There is the assumption (not quite accurate) that if a point leads to a dead-end at one time, it will always lead to a dead-end and that point should always be rejected.
    # TODO : implement a more thorough search before putting a point in the "wrong way" array. The point should have exhausted all possible paths (that is, every possible tuneable interval from that point should have been tried)
    wrong_way = []
    # dead_ends is a catalog of every dead end that has been found by the search function. The keys are all points, while the values are tuneable intervals. If a tuneable interval returns no possible tuneable points (not equal to the current point) than it is deemed a dead end, and added to that point's list of dead ends in the value array.
    dead_ends = {}
  
    max_iterations.times do |iteration|
      
      if wrong_way.include? start_vector
        puts "Aborting climb at iteration #{iteration} :("
        break
      end
      # Sorts the list of tuneable intervals by whether they can possibly bring the vector closer
      # The current point will be multiplied by the tuneable interval, across the vector
      
      #puts "- Iteration #{iteration}"
      current_point_cache = current_point.dup
      current_result = climb_func.call(current_point)
      #puts "Current point is #{current_point.to_a} with a distance of #{"%0.3f" % current_result}"
      # Initialize an array for the current point if it does not already have one
      dead_ends[current_point] == nil ? dead_ends[current_point] = [] : false
      # Generate a collection of test points with scores: [point, score]
      test_points = []
      # Sort the list of tuneable intervals by the mean hd-sum of all possible tuneable combinations operating on the current vector
      tuneable_scores = []
      for i in 1...tuneable.size
          interval_score = 0.0
          interval_count = 0
          # If the current tuneable interval is a dead end, skip it and try the next one
          (dead_ends[current_point].include? tuneable[i]) ? next : false
          for j in 0...all_candidates.size
            possible_point = current_point * (tuneable[i] ** all_candidates[j])
            all_tuneable?(possible_point, tuneable) ? true : next
            # Hard-wired to the OCM, but could possible be something else
            interval_score += MM.dist_ocm(start_vector, possible_point, config)
            interval_count += 1
          end
          ( interval_count != 0 ) ? interval_score /= interval_count : (dead_ends[current_point] << tuneable[i]; next)
          tuneable_scores << [tuneable[i], interval_score]
      end
      
      tuneable_scores.sort_by! {|x| x[1]}
      # print "#{tuneable_scores}\n"
      
      # Trying to see how long it takes to get the first result
      # exit
      
      # Clearly we are at a dead end.
      if tuneable_scores.all? {|x| x == nil}
        if path.size > 1
          wrong_way << path.pop
          #puts "WRONG WAY is #{wrong_way.to_a}"
        end
        current_point = path[-1]
        #puts "Moving back a step: #{path.to_a}"
        step_size = start_step_size
        next
      end
      
      # Decide which interval to use (based on the desired step size)
      interval_index = -1
      begin
        interval_index += 1
      end while (step_size * current_result > tuneable_scores[interval_index][1] && interval_index < tuneable_scores.size-1)
      
      #puts "#{tuneable_scores.to_a}"
      #puts "Step size is #{"%0.2f" % step_size} / #{"%0.2f" % (step_size * current_result)}"
      #puts "Chosen interval is #{tuneable_scores[interval_index][0]} with a score of #{"%0.3f" % tuneable_scores[interval_index][1]}"
      puts "#{iteration}: \tInterval: #{tuneable_scores[interval_index][0]} \tDistance: #{current_result}"
      for c in all_candidates
        # Find the new point
        new_point = current_point * (tuneable_scores[interval_index][0] ** c)
        new_point *= new_point[0] ** -1
        (wrong_way.include? new_point) ? next :
        # If all intervals are tuneable (or if we don't care), then add it to the possible candidates
        (all_tuneable?(new_point, tuneable) || !check_tuneable_intervals) ? (test_points << [new_point, climb_func.call(new_point)]) : next
        test_points.uniq!
      end
      
      #print "#{test_points}\n"
      begin
        test_points.sort_by! {|x| x[1] }
      rescue ArgumentError => ex
        puts "#{ex.message}"
      end
      
      winner = test_points[0]
      
      # If there are no possible test_points then something is wrong.
      # TODO: make this backtrack more effectively (and efficiently)
      if winner == nil
        if step_size_subtract
          step_size -= step_size_subtract 
        else
          step_size *= 0.5
        end
        step_size = min_step_size if step_size < min_step_size
        dead_ends[current_point] << tuneable_scores[interval_index][0]
        next
      end
      
      if winner[1] < current_result
        current_point = winner[0]
        # Makes the vector always begin on 1/1, whatever that may be
        if current_point[0] != HD.r
          current_point *= (current_point[0] ** -1)
        end
        path << current_point.dup
      end
    
      test_score = climb_func.call(current_point)
      if test_score < (0 + epsilon) && test_score > (0 - epsilon)
        puts "Success at iteration #{iteration}"
        break
      end
      
      if current_point == current_point_cache
        dead_ends[current_point] << tuneable_scores[interval_index][0]
        next
      end
      
      if current_point == current_point_cache && step_size > min_step_size
        # We didn't get any good results, so lower the step size
        if step_size_subtract
          step_size -= step_size_subtract 
        else
          step_size *= 0.5
        end
        step_size = min_step_size if step_size < min_step_size
        # puts "Lower step size to #{"%0.2f" % step_size}"
      elsif current_point == current_point_cache && step_size <= min_step_size
        # We didn't get any good results, and we can't lower the step size
        puts "Aborting climb at iteration #{iteration} :("
        break
      end
    end
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