require 'test/unit'
require '../hd-mm.rb'
require '../lib/search/metric_search.rb'
require '../lib/search/olm_search.rb'

class OLMSearchTest < Test::Unit::TestCase	
	def test_search
		# Within the search algorithm provided, there is an optimal search result
		
	  hd_config = HD::HDConfig.new
	  hd_config.prime_weights = [2.0,3.0,5.0,7.0,11.0]
	  # rejecting all intervals greater than two octaves and a fifth
	  hd_config.tuneable.reject! {|x| x.to_f > 8.0}
	  hd_config.reject_untuneable_intervals!
	  start_vector = HD::Ratio.from_s "1/1 2/1 3/2 2/3 16/9 32/27 8/3 2/1 3/1"
		
	  opts = {}
	  interval = 0.44444444444 / 14.0
	  opts[:epsilon] = interval / 2.0
	  opts[:hd_config] = hd_config
	  opts[:start_vector] = start_vector
	  opts[:max_iterations] = 10000
		
	  # Creating the angler
	  lowest = NArray.int(2, start_vector.shape[1]).fill(1)
	  x_bounds = [lowest, HD::Ratio.from_s("1/1 8/1 1/1 8/1 1/1 8/1 1/1 8/1 1/1")]
	  y_bounds = [lowest, HD::Ratio.from_s("1/1 28/5 1/1 28/5 1/1 28/5 1/1 28/5 1/1")]
	  x_cfg = MM::DistConfig.new({:scale => :none, :intra_delta => MM.get_ed_intra_delta, :inter_delta => MM::DELTA_FUNCTIONS[:longest_vector_abs_diff], :int_func => MM::INTERVAL_FUNCTIONS[:pairs]})
	  y_cfg = MM::DistConfig.new({:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(hd_config), :inter_delta => MM::DELTA_FUNCTIONS[:longest_vector_abs_diff], :int_func => MM::INTERVAL_FUNCTIONS[:pairs]})
	  angler = MM::Angle.new(MM.olm, MM.olm, x_bounds, x_cfg, y_bounds, y_cfg)
	  opts[:angler] = angler
	  opts[:is_scaled] = true
		
    opts[:goal_vector] = NArray[ -0.0305089, 0.00877584 ] 
		
		searcher = ::MM::OLMSearch.new(opts)
		results = searcher.search
		
		assert(results[0] == NArray[[1, 1], [1, 2], [2, 3], [3, 2], [27, 8], [81, 16], [9, 4], [3, 1], [2, 1]])
	end
end

# Current standard:
# Finished tests in 30.375140s, 0.0329 tests/s, 0.0329 assertions/s.
# 1 tests, 1 assertions, 0 failures, 0 errors, 0 skips