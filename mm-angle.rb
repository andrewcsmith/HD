require '../Morphological-Metrics/mm.rb'
require './hd.rb'
require './get_angle.rb'
require './deltas.rb'

module MM

    # Notes regarding the concept of angle in a bounded metric space:
    # The concept of a bounded metric space requires that each
    # dimension have a lowest and highest point. These points may be
    # found logically if the space is intuitive enough, but they may
    # also be found by searching. A search algorithm might employ
    # gradient descent techniques to find the diameter of a space.   
    
    class Angle
      
      attr_accessor :x_metric, :y_metric, :x_bounds, :x_cfg, :y_bounds, :y_cfg, :hd_cfg
      
      def initialize(x_metric, y_metric, x_bounds, x_cfg, y_bounds, y_cfg, hd_cfg)
        @x_metric = x_metric
        @y_metric = y_metric
        @x_bounds = x_bounds
        @x_cfg = x_cfg
        @y_bounds = y_bounds
        @y_cfg = y_cfg
        @hd_cfg = hd_cfg
        
        # Check for correct arguments
        if !((@x_bounds.is_a? Array) || (@y_bounds.is_a? Array)) then
          raise ArgumentError.new("x_bounds and y_bounds must both be of type Array")
        end
        
        @hd_cfg.reject_untuneable_intervals!
        
        # TODO: Figure out how to derive the max scale without calling the metric
        @x_cfg.scale = ->(m_diff, n_diff) {
          max_scale = @x_cfg.dup
          max_scale.scale = ->(m_diff, n_diff) {return [1.0, 1.0, 1.0]}
          return [@x_metric.call(@x_bounds[0], @x_bounds[1], max_scale), 1, 1]
        }
        @y_cfg.scale = ->(m_diff, n_diff) {
          max_scale = @y_cfg.dup
          max_scale.scale = ->(m_diff, n_diff) {return [1.0, 1.0, 1.0]}
          return [@y_metric.call(@y_bounds[0], @y_bounds[1], max_scale), 1, 1]
        }
      end
      
      def get_coordinates(v)
        NArray[@x_metric.call(v, @x_bounds[0], @x_cfg), @y_metric.call(v, @y_bounds[0], @y_cfg)]
      end
      
      def get_angle(v, o)
        v_coordinates = self.get_coordinates v
        o_coordinates = self.get_coordinates o
        coord_diff = o_coordinates - v_coordinates
        (180.0 * NMath.atan2(coord_diff[0], coord_diff[1]) / NMath::PI) - 180.0
      end
      
      # This is a function to get an angle as a basis of HD and ED 2-d space
      # Takes at least two arguments: a vector, and a desired origin.
      # The angle is relative to the vertical axis on the origin, as is the distance.
      # An optional HDConfig object may be supplied, which would help properly scale the space

      # It should be noted that this is only set up to work with the OLM; other configurations are
      # possible, however

      # Plan for refactoring:
      # 
      # * The get_angle function should be encapsulated into a class, within which the hd_cfg,
      #   ed_cfg, and all other static variables are initialized.
      # 
      # * Initializing the object with a given set of metrics on the X and Y axes should compute the
      #   lines with the maximum and minimum possible metrics on each axis. This might have to be
      #   done by hand.
      # 
      # * Optimize the get_angle algorithm to call the metrics the least number of times.
      # 
      # * If it makes sense, add get_tuneable_data to this whole thing.
      # 
      # * Possible to generalize the movement from the OLM to the OCM? (without calling
      #   get_tuneable_data again)
      # 
      # def self.get_angle(v, o, cfg = HD::HDConfig.new)
      # 
      #         lowest = NArray.int(*v.shape).fill 1
      #         highest = NArray.int(*v.shape).fill 1
      #         1..highest.shape[1] do |i|
      #           if i % 2 == 0
      #             next
      #           end
      #           highest[true,i] = HD.r(8,1)
      #         end
      # 
      #         cfg.tuneable.reject! {|x| (x.distance(HD.r, cfg) ** -1) == 0}
      #         cfg.tuneable.reject! {|x| Math.log2(x.to_f) > 3.0} # Reject everything that's over 3 octaves (the range of the violin, practically)
      # 
      #         hd_proc = get_hd_proc(cfg)
      #         ed_proc = get_ed_proc(cfg)
      #         ed_intra_delta = get_ed_intra_delta
      # 
      #         hd_cfg = MM::DistConfig.new
      #         # c_olm.scale = :absolute
      #         hd_cfg.scale = hd_proc
      #         hd_cfg.intra_delta = MM.get_harmonic_distance_delta(cfg)
      #         # At this point, we are in the logarithmic domain so we can resort to subtraction to find the
      #         # difference
      #         hd_cfg.inter_delta = MM::DELTA_FUNCTIONS[:longest_vector_abs_diff]
      #         hd_cfg.int_func = MM::INTERVAL_FUNCTIONS[:pairs]
      # 
      #         ed_cfg = MM::DistConfig.new
      #         ed_cfg.scale = ed_proc
      #         ed_cfg.intra_delta = ed_intra_delta
      #         # At this point, we are in the logarithmic domain so we can resort to subtraction to find the
      #         # difference
      #         ed_cfg.inter_delta = MM::DELTA_FUNCTIONS[:longest_vector_abs_diff]
      #         ed_cfg.int_func = MM::INTERVAL_FUNCTIONS[:pairs]
      # 
      #         goal_angle = -73.95
      #         # goal_angle = 106.05
      # 
      #         hdistance = MM.dist_olm(v, o, hd_cfg)
      #         edistance = MM.dist_olm(v, o, ed_cfg)
      # 
      #         # Get the value relative to the lowest
      #         hd_abs = MM.dist_olm(v, lowest, hd_cfg)
      #         ed_abs = MM.dist_olm(v, lowest, ed_cfg)
      # 
      #         origin_abs = [MM.dist_olm(o, lowest, hd_cfg), MM.dist_olm(o, lowest, ed_cfg)]
      # 
      #         # puts "#{hdistance}, #{edistance}, #{hd_abs}, #{ed_abs}"
      # 
      #         # Get the sign of the value
      #         hd_sgn = (hd_abs > origin_abs[0]) ? 1.0 : -1.0
      #         ed_sgn = (ed_abs > origin_abs[1]) ? 1.0 : -1.0
      # 
      #         # Populates the hash with the vector as the key
      #         hc = hdistance * hd_sgn # Get the harmonic coordinates of v (relative to o)
      #         ec = edistance * ed_sgn # Get the euclidian coordinates of v (relative to o)
      #         angle = 180.0 * (Math.atan2(ec, hc) / Math::PI) # Get the angle of v relative to o
      #         cost = [(goal_angle - angle).abs, (goal_angle + 180.0 - angle).abs].min # The cost is the deviation (in degrees) from the ideal line
      #         distance = Math.sqrt(hc ** 2 + ec ** 2) # Distance from o, based on both metrics
      # 
      #         # Return the NArray of values
      #         NArray[hc, ec, angle, cost, distance]
      #       end
    end
    
end

__END__

# Copy and paste all this stuff below into the IRB to set up the environment

v1 = NArray[[1, 1], [2, 1], [3, 2], [2, 3], [16, 15], [32, 45], [8, 5], [6, 5], [9, 5]]
o = NArray[[1, 1], [2, 1], [3, 2], [2, 3], [16, 9], [32, 27], [8, 3], [2, 1], [3, 1]]
hd_cfg = HD::HDConfig.new
hd_cfg.prime_weights = [2,3,5,7,11]
hd_cfg.reject_untuneable_intervals!
lowest = HD::Ratio.from_s "1/1 1/1 1/1 1/1 1/1 1/1 1/1 1/1 1/1"
x_bounds = [lowest, HD::Ratio.from_s("1/1 8/1 1/1 8/1 1/1 8/1 1/1 8/1 1/1")]
y_bounds = [lowest, HD::Ratio.from_s("1/1 28/5 1/1 28/5 1/1 28/5 1/1 28/5 1/1")]

x_metric = MM.olm
y_metric = MM.olm
x_cfg = MM::DistConfig.new({:scale => :none, :intra_delta => MM.get_ed_intra_delta, :inter_delta => MM::DELTA_FUNCTIONS[:longest_vector_abs_diff], :int_func => MM::INTERVAL_FUNCTIONS[:pairs]})
y_cfg = MM::DistConfig.new({:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(hd_cfg), :inter_delta => MM::DELTA_FUNCTIONS[:longest_vector_abs_diff], :int_func => MM::INTERVAL_FUNCTIONS[:pairs]})

angler = MM::Angle.new(x_metric, y_metric, x_bounds, x_cfg, y_bounds, y_cfg, hd_cfg)
