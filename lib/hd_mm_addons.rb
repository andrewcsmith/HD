# This is an inter_delta function to compare the harmonic distance between
# corresponding elements of a vector.
# 
# The only issue with MM compatability is that the configuration must be an
# outside variable, and not part of the proc, or it must be defined with the
# definition of the proc. In other words, it might make more sense to define a
# function that returns a proc based on the config that is passed into it.
# This way, a proc could then be passed to the MM functions and remain
# effective (linked to an outside HDConfig).
# 
# In combinatorial metrics, the intra_delta acts upon each of the possible
# pair combinations. By contrast, a linear metric is passed two NArrays filled
# with objects that need to be acted upon, in this case HD::Ratio objects, of
# [0...a.total-1] and [1...a.total], so that each successive pair is operated
# upon.
# 
# Refactored into one Proc: this harmonic_distance_delta will respond
# correctly to both an HD::Ratio (as in combinatorial metrics) and an NArray
# (as in linear metrics). 

module MM
  # Returns a Proc to be used as an intra_delta in a given DistConfig object. This Proc measures the harmonic distance between successive intervals. It takes an HD::HDConfig object (a reference), which allows it to change as the HDConfig object's settings are changed.
  # 
  # See its use in hd_test.rb, #test_olm for more information.
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
        dist_vectors[i] = HD::Ratio.from_na(a[true,i]).distance(HD::Ratio.from_na(b[true,i]), config).abs
      end
      return dist_vectors
    }
  end
  
  # This gives a vector (of length v.length - 1) with the intervals between successive points.
  # For use as a delta in MM.vector_delta
  def self.get_inner_interval_delta(config = HD::HDConfig.new)
    ->(a, b) {
      if a.is_a? HD::Ratio
        return a.distance(b, config)
      elsif a.is_a? Array # If it's an array, we'll need to make it an NArray first
        a = NArray.to_na(a)
        b = NArray.to_na(b)
      elsif a.is_a? NArray # If the first argument is an NArray
        true # No prep needed
      else
        raise Exception.new("get_inner_interval_delta only works with NArray or HD::Ratio\nYou passed it an #{a.class}")
      end
      dist_vectors = NArray.int(a.shape[0],a.shape[1]) # the vector needs to be one shorter than the source
      for i in 0...dist_vectors.shape[1]
        dist_vectors[true,i] = HD.r(*a[true,i]) / HD.r(*b[true,i])
      end
      return dist_vectors
    }
  end
  
  # Given a list of inner intervals and a start location, returns the absolute vector.
  def self.vector_from_differential(m, start = HD.r)
    # Generate blank array for output
    out = NArray.int(m.shape[0], m.shape[1]+1)
    out[true,0] = start
    (out.shape[1]-1).times do |i|
      out[true,i+1] = HD.r(*(out[true,i] * m[true,i]))
    end
    return out
  end
  
  # Instead of passing each subsequent item, [+:pairs+] passes pairs of entries for use in HD::Ratio objects
  MM::INTERVAL_FUNCTIONS[:pairs] = lambda {|m| m[true,1...m.shape[1]].reshape(2,m.shape[1]-1)}
  
  # Takes two vectors [v, o] and tries every inversion of the inner intervals
  # such that the vector v has the lowest possible distance based on the OLD
  # metric from vector o. As the only thing being changed is the inversion of
  # the corresponding intervals (and not their magnitudes), the distance based
  # on the OLM remains unchanged. In practical usage, this minimizes the
  # musical effect of the changing contours of successive vectors, placing the
  # focus on other changes such as change of magnitude of harmonic distance
  # and pitch distance.
  def self.get_lowest_old(v, o, hd_config = HD::HDConfig.new, ignore_tuneable = false, tuned_range = [HD.r(2,3), HD.r(12,1)])
		o_dec = ratios_to_floats(o)
			
    out = []
    delta = get_inner_interval_delta(hd_config)
    int_func = MM::INTERVAL_FUNCTIONS[:pairs]
    # TODO: Fix this vector_delta so that it gives the FULL length
    # it's currently leaving off the last interval
    inner_v = vector_delta(v, 1, delta, int_func)
    possible_vectors = []
    
    [-1,1].repeated_permutation(inner_v.shape[1]) do |x|
      # Create NArray to hold the possible vector
      possible_inner_v = NArray.int(*inner_v.shape)
      
      # Iterate through each inner_v with each permutation of exponents
      (0...inner_v.shape[1]).each do |y|
        # Must convert to a HD::Ratio so that ** works like we want it to
        r = HD.r(*inner_v[true,y])
        possible_inner_v[true,y] = r ** x[y]
      end
      
      # Convert this back into a normalized full vector (so we can check tuneability)
      v_cand = vector_from_differential possible_inner_v
      # The range for this function must be 4 octaves above the D string, likely played with art. harmonics
      # so that it is possible to play every vector.
      if ignore_tuneable || HD.all_tuneable?(v_cand, hd_config.tuneable, tuned_range)
        # puts "tuneable: #{v_cand.to_a}"
        possible_vectors << v_cand
      end
    end
    possible_vectors.sort_by! do |x|
      x_dec = ratios_to_floats(o)
      MM.dist_old(x_dec, o_dec)
    end
    possible_vectors
  end
	# helper method for the above OLD
	def self.ratios_to_floats(v)
		p = NArray.float(*v.shape)
		for i in 0...v.total
			p[i] = v[i].to_f
		end
		p[0,true] / p[1,true]
	end
  
  def self.get_hd_proc(cfg = HD::HDConfig.new)
    hd_proc = ->(m_diff, n_diff) {
      # The global scaling (highest possible value) is the largest possible distance
      return [cfg.tuneable.sort_by {|x| x.distance(HD.r, cfg)}[-1].distance, 1, 1]
    }
  end

  def self.get_ed_proc(cfg = HD::HDConfig.new)
    # Scaling proc for Euclidian Distance
    # This is scaled based on the range of the violin (technically impossible, since all vectors are normalized)
    # Returns [scale global, scale m, scale n]
    ed_proc = ->(m_diff, n_diff) {
      # We want to scale to the largest interval in normal distance
      return [Math.log2(cfg.tuneable.sort_by {|x| x.to_f}[-1].to_f), 1, 1]
    }
  end

  # This provides the delta function for Euclidian Distance (should be an intra_delta)
  def self.get_ed_intra_delta
    # intra-vector delta for Euclidian Distance
    ed_intra_delta = ->(a, b) {
      if a.is_a? Array # If it's an array, we'll need to make it an NArray first
        a = NArray.to_na(a)
        b = NArray.to_na(b)
      end
      dim = a.shape[1] # Get the length of the series of ratios
      res = NArray.float(dim) # This is where we'll store our vectors

      dim.times { |i| res[i] = (Math.log2(a[0,i].to_f / a[1,i].to_f) - Math.log2(b[0,i].to_f / b[1,i].to_f)).abs }
      return res
    }
  end
  
  def self.sort_by_cost(cost, interval_index)
    ind = cost.eq cost.sort[interval_index] # Sort by cost
    ind = ind.where[0] # Find the lowest possible cost
    ind_x = ind % cost.shape[0]
    ind_y = ind / cost.shape[0]
    return [ind_x, ind_y]
  end
  

  # Deprecated: Use get_harmonic_distance_delta
  # Returns a Proc for harmonic distance, but with a permanent HDConfig Object attached
  def self.get_harmonic_distance_delta_single(config = HD::HDConfig.new)
    ->(a, b) { 
      warn "get_harmonic_distance_delta_single deprecated. Use get_harmonic_distance_delta."
      a.distance(b, config) }
  end
end