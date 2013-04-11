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
  
  def self.get_frequencies_from_vector(v, base = 440.0)
    a = NArray.float(3,v.shape[1])
    a[0..1,true] = v
    a[2,true] = a[0,true] / a[1,true]
    
    b = a[2,true] * base
    b
  end
  
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
  
  # This gives a vector (of length v.length - 1) with the change in intervals from entry to entry
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
  
  # Given a list of inner intervals and a start location, returns the absolute vector
  def self.vector_from_differential(m, start = HD.r)
    # Generate blank array for output
    out = NArray.int(m.shape[0], m.shape[1]+1)
    out[true,0] = start
    (out.shape[1]-1).times do |i|
      out[true,i+1] = HD.r(*(out[true,i] * m[true,i]))
    end
    return out
  end
  
  MM::INTERVAL_FUNCTIONS[:pairs] = lambda {|m| m[true,1...m.shape[1]].reshape(2,m.shape[1]-1)}
  
  # # Takes two vectors [v, o] and flips the inner intervals back and forth such that
  # # the vector v has the lowest possible distance (OLD) from vector o. The distance
  # # of the OLM between both vectors is unaffected.
  # def self.get_lowest_old(v, o, hd_config = HD::HDConfig.new, ignore_tuneable = false, tuned_range = [HD.r(2,3), HD.r(16,1)])
  #   o_dec = o[0,true].to_f / o[1,true].to_f
  #   
  #   out = []
  #   delta = get_inner_interval_delta(hd_config)
  #   int_func = MM::INTERVAL_FUNCTIONS[:pairs]
  #   # TODO: Fix this vector_delta so that it gives the FULL length
  #   # it's currently leaving off the last interval
  #   inner_v = vector_delta(v, 1, delta, int_func)
  #   possible_vectors = []
  #   
  #   [-1,1].repeated_permutation(inner_v.shape[1]) do |x|
  #     # Create NArray to hold the possible vector
  #     possible_inner_v = NArray.int(*inner_v.shape)
  #     
  #     # Iterate through each inner_v with each permutation of exponents
  #     (0...inner_v.shape[1]).each do |y|
  #       # Must convert to a HD::Ratio so that ** works like we want it to
  #       r = HD.r(*inner_v[true,y])
  #       possible_inner_v[true,y] = r ** x[y]
  #     end
  #     
  #     # Convert this back into a normalized full vector (so we can check tuneability)
  #     v_cand = vector_from_differential possible_inner_v
  #     # The range for this function must be 4 octaves above the D string, likely played with art. harmonics
  #     # so that it is possible to play every vector.
  #     if ignore_tuneable || all_tuneable?(v_cand, hd_config.tuneable, tuned_range)
  #       # puts "tuneable: #{v_cand.to_a}"
  #       possible_vectors << v_cand
  #     end
  #   end
  #   possible_vectors.sort_by! do |x|
  #     x_dec = x[0,true].to_f / x[1,true].to_f
  #     MM.dist_old(x_dec, o_dec)
  #   end
  #   possible_vectors
  # end
  
  # def self.get_lowest_ocd(v, o, hd_config = HD::HDConfig.new)
  #   o_dec = o[0,true].to_f / o[1,true].to_f
  #   
  #   out = []
  #   delta = get_inner_interval_delta(hd_config  )
  #   int_func = MM::INTERVAL_FUNCTIONS[:pairs]
  #   # TODO: Fix this vector_delta so that it gives the FULL length
  #   # it's currently leaving off the last interval
  #   inner_v = vector_delta(v, 1, delta, int_func).to_a
  #   possible_vectors = []
  #   
  #   inner_v.permutation(inner_v.size).each do |x|
  #     x = NArray.to_na(x)
  #     v_cand = vector_from_differential x
  #     if all_tuneable?(v_cand, hd_config.tuneable)
  #       # puts "tuneable: #{v_cand.to_a}"
  #       possible_vectors << v_cand
  #     end
  #   end
  #   possible_vectors.sort_by! do |x|
  #     x_dec = x[0,true].to_f / x[1,true].to_f
  #     MM.dist_ocd(x_dec, o_dec)
  #   end
  #   possible_vectors
  # end 

  # Deprecated: Use get_harmonic_distance_delta
  # Returns a Proc for harmonic distance, but with a permanent HDConfig Object attached
  def self.get_harmonic_distance_delta_single(config = HD::HDConfig.new)
    ->(a, b) { 
      warn "get_harmonic_distance_delta_single deprecated. Use get_harmonic_distance_delta."
      a.distance(b, config) }
  end
end