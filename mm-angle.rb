require '../Morphological-Metrics/mm.rb'
require './hd.rb'
require './get_angle.rb'
require './deltas.rb'

module MM

    # The Angle class provides a simple way of projecting a bounded
    # 2-dimensional Euclidian space onto two metric dimensions and
    # finding Euclidian angles within that space.
    # 
    # The Angle object is first initialized with two metrics: for the
    # x-dimemsion and y-dimension. These are passed to the ::new method
    # along with their respective MM::DistConfig objects. Finally, the
    # x_bounds and y_bounds arguments are arrays, [m, n], where m is the
    # "lowest" possible value in the bounded space and n is the
    # "highest" possible value.
    # 
    # For example, in <em>Topology (phases of this difference)</em>, the
    # x-dimension is a metric space of Ordered Linear Magnitude
    # (Polansky), using Tenney's harmonic distance as its intra-delta
    # function. For a vector of length n, the OLM will give a vector of
    # length n-1 that is the harmonic distance between each point and
    # its successor. The entire piece is then set in a metric space
    # comprising all tuneable intervals (taken from Marc Sabat's
    # research), only using up to the 11-limit ratios, and only those
    # which will fit in the range of a violin. Therefore, the "lowest"
    # point in this dimension is a unison -- 1/1, 1/1, 1/1, 1/1, etc. --
    # and the "highest" point is one which repeatedly travels the
    # maximum harmonic distance within the set of 11-limit tuneable
    # intervals -- 1/1, 28/5, 1/1, 28/5, etc. (The OLM, as with many of
    # Polansky's Morphological Metrics, allows for multiple vectors of
    # the same distance. Another "highest" vector might be "1/1, 28/5,
    # 784/25, 28/5, 1/1, 5/28", etc., because each of the internal
    # intervals is the same harmonic distance. For simplicity, I have
    # listed these in their most-compressed form.)
    # 
    # Once the object is initialized, it is relatively simple to use.
    # The coordinates of any interval can be determined, and therefore
    # it is also simple to find the angle of one coordinate relative to
    # another. This angle assumes that 0-degrees (and 360-degrees) is
    # the y-axis.
    # 
    # ==Scaling:
    # The functions get_scaled_coordinates_from_reference and
    # get_scaled_angle are used to scale the metric space on both sides
    # of a given origin, such that any distance (up to 0.5) may be
    # theoretically obtained within that space. The
    # get_scaled_coordiantes_from_reference function allows for a point
    # in the middle of the space, where the remaining space on either
    # dimension is normalized to 0.5. This means that while the largest
    # distance across the entire space is still 1.0, the "origin" is
    # theoretically in the center of the space, which is warped on
    # either side. This allows for inscribing a theoretical "circle" of
    # any radius up to 0.5 within the space, with the origin as its
    # center.
    class Angle
      
      attr_accessor :x_metric, :y_metric, :x_bounds, :x_cfg, :y_bounds, :y_cfg, :hd_cfg
      attr_reader :reference_interval, :x_scale, :y_scale
      
      def initialize(x_metric, y_metric, x_bounds, x_cfg, y_bounds, y_cfg)
        @x_metric = x_metric
        @y_metric = y_metric
        @x_bounds = x_bounds
        @x_cfg = x_cfg
        @y_bounds = y_bounds
        @y_cfg = y_cfg
        
        # Check for correct arguments
        if !((@x_bounds.is_a? Array) || (@y_bounds.is_a? Array)) then
          raise ArgumentError.new("x_bounds and y_bounds must both be of type Array")
        end
        
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
      
      # Set the reference "origin"
      def reference_interval= r
        if r.is_a? NArray
          @reference_interval = r
        else
          warn "@reference_interval was not set. Please pass an NArray to get_coordinates_from_reference."
        end
      end
      
      # Find the coordinates of a given point in the global metric space,
      # relative to the lowest point
      def get_coordinates(v)
        x = @x_metric.call(v, @x_bounds[0], @x_cfg)
        y = @y_metric.call(v, @y_bounds[0], @y_cfg)
        NArray[x, y]
      end
      
      # Find the coordinates of a given point relative to a reference "origin"
      def get_coordinates_from_reference(v, *r)
        if r.size > 0
          if r[0].is_a? NArray
            @reference_interval = r[0]
          else
            warn "@reference_interval was not set. Please pass an NArray to get_coordinates_from_reference."
          end
        elsif @reference_interval == nil
          raise "Please first set reference_interval."
        end
        get_coordinates(v) - get_coordinates(@reference_interval)
      end
      
      def get_scaled_coordinates_from_reference(v, *r)
        if r.size > 0
          if r[0].is_a? NArray
            @reference_interval = r[0]
          else
            warn "@reference_interval was not set. Please pass an NArray to get_coordinates_from_reference"
          end
        elsif @reference_interval == nil
          raise "Please first set reference_interval."
        end
        coords = get_coordinates(@reference_interval)
        @x_scale = coords[0] / (1.0 - coords[0])
        @y_scale = coords[1] / (1.0 - coords[1])
        
        unscaled_coords = get_coordinates(v) - get_coordinates(@reference_interval)
        unscaled_coords[0] > 0.0 ? unscaled_coords[0] *= @x_scale : unscaled_coords[0] /= @x_scale
        unscaled_coords[1] > 0.0 ? unscaled_coords[1] *= @y_scale : unscaled_coords[1] /= @y_scale
        
        unscaled_coords
      end
      
      # Find the angle of a given point, using a second point as an origin.
      # The angle assumes the the y-axis (vertical) is 0 degrees.
      def get_angle(v, o)
        coord_diff = self.get_coordinates_from_reference(v, o)
        (180.0 * NMath.atan2(coord_diff[0], coord_diff[1]) / NMath::PI)
      end
      
      def get_scaled_angle(v, o)
        coord_diff = self.get_scaled_coordinates_from_reference(v, o)
        (180.0 * NMath.atan2(coord_diff[0], coord_diff[1]) / NMath::PI)
      end
    end
end

__END__

# Copy and paste all this stuff below into the IRB to set up the environment

# Source vectors
v1 = NArray[[1, 1], [2, 1], [3, 2], [2, 3], [16, 15], [32, 45], [8, 5], [6, 5], [9, 5]]
o = NArray[[1, 1], [2, 1], [3, 2], [2, 3], [16, 9], [32, 27], [8, 3], [2, 1], [3, 1]]

# The setup:
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

angler = MM::Angle.new(x_metric, y_metric, x_bounds, x_cfg, y_bounds, y_cfg)