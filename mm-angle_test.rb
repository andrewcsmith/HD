require './mm-angle.rb'
require 'test/unit'

class MMTest < Test::Unit::TestCase
  
  def test_angle
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
    
    # Vector 1 of west-northwest in Topology (phases of this difference)
    assert_in_delta(-67.1786575926054, angler.get_angle(v1, o), 0.001)
  end
end