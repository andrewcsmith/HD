# The beginnings of a search function to find pitches for a piece for trombones.
# 
# TODO:
# [ ] Override the necessary methods in MetricSearch:
#     * :get_cost
#     * :get_candidate_list
#     * :get_candidate
# [ ] Create an instance variable to allow the cost value of candidate_list to
#     persist from iteration to iteration, so that we don't have to keep calling
#     it over and over again.
# [ ] Each time the player hits the outer edge of the space, it should trigger a
#     slide-position change. In addition, the frequency of slide changes should
#     be measured and run through its own metrics. Perhaps this could impact the
#     dynamic level, or the rhythm of the entrances, or the way the strings
#     interact with the trombones, or some other parameter of the composition.
# 

module MM
  class TromboneSearch < MetricSearch
    attr_accessor :start_vector, :current_point
    
    # Range of harmonics for each voice
    # NArray.int(2, 2, 4):
    # dim-0: harmonic expressed as a ratio
    # dim-1: lower & upper range
    # dim-2: each of the 4 voices
    @@range = NArray[[[1, 1], [8, 1]], [[2, 1], [10, 1]], [[3, 1], [12, 1]], [[4, 1], [16, 1]]]
        
    def initialize opts = { }
      super opts
      if !@start_vector.is_a? NArray
        raise ArgumentError, ":start_vector must be NArray. You passed a #{@start_vector.class}."
      elsif @start_vector.shape != [2,2,4]
        raise ArgumentError, ":start_vector must be shape [2,2,4]. You passed #{@start_vector.shape.to_a}"
      end
      @metric = opts[:metric] || raise(ArgumentError, "please provide a metric to TromboneSearch")
      @cost_cache = {}
    end
    
    def prepare_search
      super
      # We want these to be reset for every search
      @candidate_list_old = true
      @cost_cache = {}
      @slide_position_index = 0
    end
    
    def prepare_each_run
      if @initial_run
        @candidate_list_old = true
      end
      super
    end
    
    # Cost function for a candidate. This is where the magic happens.
    def get_cost candidate
      # If we've already found the cost at one point, return it
      if @cost_cache.has_key? candidate.hash
        return @cost_cache[candidate.hash]
      end
      # Convert the candidate into a string of ratios to call it with our Morphological Metric
      ratio_vector = parameter_vector_to_ratio_vector candidate
      start_vector = parameter_vector_to_ratio_vector @start_vector
      # Judge these based on their distance from the goal vector
      @cost_cache[candidate.hash] = (@metric.call(ratio_vector, start_vector) - @goal_vector).abs
    end
    
    # Gets a list of adjacent points
    # In this case it finds every possible partial of a given slide position
    def get_candidate_list
      # If the list is old, we need a new one
      if @candidate_list_old
        point = @current_point.dup
        # Load it up with the possible permutations
        # old vector, which contained 65,536 permutations
        # harmonic_vector = (1..16).to_a.repeated_permutation(4)
        # the new format looks for all permutations that are a single
        # adjacent harmonic
        
        harmonic_vector = [-1, 0, 1].repeated_permutation(4)
        # what if we only want to change one voice per step?
        # let's try this:
        # harmonic_vector = [[-1, 0, 0, 0], [0, -1, 0, 0], [0, 0, -1, 0], [0, 0, 0, -1], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
        candidate_list = NArray.int(2, 2, 4, harmonic_vector.size)
        # Assign the point, adding the final dimension as a dummy dimension so that it
        # maps properly      
        candidate_list[true, true, true, true] = point.newdim(3)
        # We want all adjacent ratios
        candidate_list[0, 1, true, true] += NArray.to_na(harmonic_vector.to_a)
        # This creates a new, blank-slate object without the Enumerable methods
        add_enumeration candidate_list
        candidate_list = candidate_list.select {|x| is_in_range? x}
        # The following two lines turn the candidate_list into an Enumerable NArray
        # but I'm not sure if they don't break eveything:
        # candidate_list = NArray.to_na(candidate_list)
        # add_enumeration candidate_list
        @candidate_list = candidate_list
      end
      # return the list
      @candidate_list
    end
    
    # Select a candidate based on best-first, offset by an index
    def get_candidate(candidate_list, index)
      # puts "\nChoosing point at index #{index}, from #{candidate_list.inspect}"
      candidate_list.sort! do |c|
        # Crazy hack, but required because we only want to override the #each method for
        # the one object. Without creating a new NArray and filling it, all NArrays
        # created as parts of candidate_list would retain the #each method of the master
        # object        
        empty = NArray.int(*c.shape)
        true_array = *Array.new(empty.dim, true)
        empty[*true_array] = c[*true_array]
        get_cost empty
      end
      candidate = candidate_list[index]
      # puts "\nCandidate: #{candidate.inspect}\nDistance: #{get_cost candidate}"
      candidate
      # NOTE: Because #sort (from Enumerable) returns an Array, we only need to ask
      # for the single-digit index, without the whole array of true args.            
    end
    
    def jump_back
      # @banned_points[@path[-1].hash] = @path[-1]
      @slide_position_index = 0
      new_slide_positions = @current_point
      while @banned_points.has_key?(new_slide_positions.hash) || @path.include?(new_slide_positions)
        new_slide_positions = choose_slide_candidate @slide_position_index
        @slide_position_index += 1
      end
      if new_slide_positions
        # puts "New Slide Positions: #{new_slide_positions.inspect}"
        @current_point = new_slide_positions
        path << @current_point
        @current_cost = get_cost @current_point
        # @banned_points.delete @start_vector.hash
        if @debug_level > 1
          puts "jumping back!"
          puts "New slide position is #{current_point.inspect}"
        end
      else
        super
      end
    end
    
    def keep_going
      # 
    end
    
    # ================ #
    # DEBUG  FUNCTIONS #
    # ================ #
    
    def debug_final_report
      super
    end
    
    # ================ #
    # HELPER FUNCTIONS #
    # ================ #
    
    def parameters_to_ratio p
      # Validate argument
      if !p.is_a?(NArray) || p.shape != [2,2]
        raise ArgumentError, "parameters_to_ratio only accepts NArray of shape [2, 2]. You passed #{p.inspect}"
      end
      # Multiply the dimensions together to get the ratio
      p = HD::Ratio[*p[true, 0]] * HD::Ratio[*p[true, 1]]
      p
    end
    
    def parameter_vector_to_ratio_vector p
      # Validate argument
      if !p.is_a?(NArray) || p.shape[0..1] != [2,2] || p.dim != 3
        if p.is_a?(Array)
          parameter_vector_to_ratio_vector NArray.to_na(p)
        end
        raise ArgumentError, "parameter_vector_to_ratio_vector only accepts 3-dimensional NArrays of shape [2, 2, n]\nYou sent us a #{p.inspect}"
      end
      ratio_vector = NArray.int(2, p.shape[2])
      p.shape[2].times do |i|
        ratio_vector[true, i] = parameters_to_ratio(p[true, true, i])
      end
      ratio_vector
    end
    
    # Adds the Enumerable module to the Eigenclass of a specific object
    # this will override the #sort and #each functionality
    def add_enumeration n
      # Open up the Eigenclass to add a few Enumerator methods
      class << n
        # We want to be able to sort and reject candidates. Note that this also works
        # with nested loops, and it always iterates over the outermost dimension
        def each
          true_args = Array.new(self.dim-1, true)
          self.shape[-1].times do |i|
            yield self[*true_args, i]
          end
        end
        # Including Enumerable so that we can use reject and all those goodies
        include Enumerable
      end
    end
    
    def is_in_range? point
      # Ensure we can Enumerate over this outermost dimension
      add_enumeration point
      results = []
      point.each_with_index do |y, i|
        # puts "#{y.inspect}"
        position = HD::Ratio[*y[true, 0]]
        harmonic = y[0, 1]
        if harmonic < @@range[0, 0, i]
          results << false
        elsif harmonic > @@range[0, 1, i]
          results << false
        elsif position < HD::Ratio[9, 16]
          results << false
        elsif position > HD::Ratio[1, 1]
          results << false
        else
          results << true
        end
      end
      results.all?
    end
    
    def get_slide_candidates point
      adjacency_vector = [[-1, 0, 0, 0], [0, -1, 0, 0], [0, 0, -1, 0], [0, 0, 0, -1], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
      adjacent_points = adjacency_vector.map do |v|
        # puts "Trying #{v.inspect}"
        adjacent_point = point.dup
        adjacent_point[0, 1, true] += v
        add_enumeration adjacent_point
        # If it's already of range, skip it
        is_in_range?(adjacent_point) ? true : next
        adjacent_point[true, 1, true].each_with_index do |a, i|
          # This should, hopefully, give us the same pitch
          harmonic_movement = (HD::Ratio[*point[true, 1, i]] / HD::Ratio[*adjacent_point[true, 1, i]])
          adjacent_point[true, 0, i] = HD::Ratio[*adjacent_point[true, 0, i]] * harmonic_movement
        end
        # Check to see if it's in range before returning. If it's not, we go to the next and there's nil
        is_in_range?(adjacent_point) ? adjacent_point : next
      end
      # Remove the nils and return
      adjacent_points.select {|p| p}
    end
    
    def choose_slide_candidate index=0
      candidates = get_slide_candidates @current_point
      current_slide = @current_point[true, 0, true]
      candidates.sort_by! do |c|
        # We only want to evaluate on the outermost range
        slide = c[true, 0, true]
        m = @metric.call(slide, current_slide)
        # puts "#{c.inspect}\nDistance: #{m}"
        m
      end
      candidates[index]
    end
  end
end