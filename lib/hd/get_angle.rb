module MM
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
end