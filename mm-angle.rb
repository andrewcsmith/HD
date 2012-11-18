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
    
    # Is there also a way to get the angle without necessarily
    # knowing the maximum dimension? The two metrics must be scaled
    # to one another – however, the max scaling of each metric is
    # really just a compositional decision. There's nothing to say
    # that one metric could not be scaled wildly differently than the
    # other.
    
    class Angle
      
      attr_accessor :x_metric, :y_metric, :x_bounds, :x_cfg, :y_bounds, :y_cfg, :hd_cfg, :reference_interval
      
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
      
      def reference_interval= r
        if r[0].is_a? NArray
          @reference_interval = r[0]
        else
          warn "@reference_interval was not set. Please pass an NArray to get_coordinates_from_reference"
        end
      end
      
      def get_coordinates(v)
        NArray[@x_metric.call(v, @x_bounds[0], @x_cfg), @y_metric.call(v, @y_bounds[0], @y_cfg)]
      end
      
      def get_coordinates_from_reference(v, *r)
        if r.size > 0
          if r[0].is_a? NArray
            @reference_interval = r[0]
          else
            warn "@reference_interval was not set. Please pass an NArray to get_coordinates_from_reference"
          end
        elsif @reference_interval == nil
          raise "Please first set reference_interval."
        end
        
        get_coordinates(v) - get_coordinates(@reference_interval)
      end
      
      def get_angle(v, o)
        v_coordinates = self.get_coordinates v
        o_coordinates = self.get_coordinates o
        coord_diff = o_coordinates - v_coordinates
        (180.0 * NMath.atan2(coord_diff[0], coord_diff[1]) / NMath::PI) - 180.0
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

angler = MM::Angle.new(x_metric, y_metric, x_bounds, x_cfg, y_bounds, y_cfg, hd_cfg)
