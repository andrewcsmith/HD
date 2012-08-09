require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'
require 'nokogiri'

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

      dim.times { |i| res[i] = (Math.log2(a[true,i][0].to_f / a[true,i][1].to_f) - Math.log2(b[true,i][0].to_f / b[true,i][1].to_f)).abs }
      return res
    }
  end

  # This is a function to get an angle as a basis of HD and ED 2-d space
  # Takes at least two arguments: a vector, and a desired origin.
  # The angle is relative to the vertical axis on the origin, as is the distance.
  # An optional HDConfig object may be supplied, which would help properly scale the space

  # It should be noted that this is only set up to work with the OLM; other configuration are possible, however
  def self.get_angle(v, o, cfg = HD::HDConfig.new)
    
    lowest = NArray.int(*v.shape).fill 1
  
    cfg.tuneable.reject! {|x| (x.distance(HD.r, cfg) ** -1) == 0}
    cfg.tuneable.reject! {|x| Math.log2(x.to_f) > 3.0} # Reject everything that's over 3 octaves (the range of the violin, practically)
  
    hd_proc = get_hd_proc(cfg)
    ed_proc = get_ed_proc(cfg)
    ed_intra_delta = get_ed_intra_delta

    hd_cfg = MM::DistConfig.new
    # c_olm.scale = :absolute
    hd_cfg.scale = hd_proc
    hd_cfg.intra_delta = MM.get_harmonic_distance_delta(cfg)
    # At this point, we are in the logarithmic domain so we can resort to subtraction to find the difference
    hd_cfg.inter_delta = MM::DELTA_FUNCTIONS[:longest_vector_abs_diff]
    hd_cfg.int_func = MM::INTERVAL_FUNCTIONS[:pairs]

    ed_cfg = MM::DistConfig.new
    ed_cfg.scale = ed_proc
    ed_cfg.intra_delta = ed_intra_delta
    # At this point, we are in the logarithmic domain so we can resort to subtraction to find the difference
    ed_cfg.inter_delta = MM::DELTA_FUNCTIONS[:longest_vector_abs_diff]
    ed_cfg.int_func = MM::INTERVAL_FUNCTIONS[:pairs]

    goal_angle = -73.95
    # goal_angle = 106.05

    hdistance = MM.dist_olm(v, o, hd_cfg)
    edistance = MM.dist_olm(v, o, ed_cfg)

    # Get the value relative to the lowest
    hd_abs = MM.dist_olm(v, lowest, hd_cfg)
    ed_abs = MM.dist_olm(v, lowest, ed_cfg)
    
    origin_abs = [MM.dist_olm(o, lowest, hd_cfg), MM.dist_olm(o, lowest, ed_cfg)]
    
    # puts "#{hdistance}, #{edistance}, #{hd_abs}, #{ed_abs}"

    # Get the sign of the value
    hd_sgn = (hd_abs > origin_abs[0]) ? 1.0 : -1.0
    ed_sgn = (ed_abs > origin_abs[1]) ? 1.0 : -1.0

    # Populates the hash with the vector as the key
    hc = hdistance * hd_sgn # Get the harmonic coordinates of v (relative to o)
    ec = edistance * ed_sgn # Get the euclidian coordinates of v (relative to o)
    angle = 180.0 * (Math.atan2(ec, hc) / Math::PI) # Get the angle of v relative to o
    cost = [(goal_angle - angle).abs, (goal_angle + 180.0 - angle).abs].min # The cost is the deviation (in degrees) from the ideal line
    distance = Math.sqrt(hc ** 2 + ec ** 2) # Distance from o, based on both metrics

    # Return the NArray of values
    NArray[hc, ec, angle, cost, distance]
  end
  
  def self.sort_by_cost(cost, interval_index)
    ind = cost.eq cost.sort[interval_index] # Sort by cost
    ind = ind.where[0] # Find the lowest possible cost
    ind_x = ind % cost.shape[0]
    ind_y = ind / cost.shape[0]
    return [ind_x, ind_y]
  end
end