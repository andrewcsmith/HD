require '../../hd-mm.rb'
require '../../lib/search/trombone_search.rb'
require 'test/unit'

class TromboneTest < Test::Unit::TestCase
	
	def setup
		start_vector = NArray[[[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]]]
		goal_vector = 0.1
		metric = MM.ucm
		# For metric, we call 
		@opts = {:start_vector => start_vector, :goal_vector => goal_vector, :metric => metric}
	end
	
	def test_trombone_search_should_require_start_vector_narray
		assert_raise ArgumentError do
			@opts[:start_vector] = [[[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]]]
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_require_start_vector_narray_of_shape_2_2_4
		assert_raise ArgumentError do
			@opts[:start_vector] = NArray[[[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]]]
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_require_goal_vector
		assert_raise ArgumentError do
			@opts[:goal_vector] = nil
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_require_metric
		assert_raise ArgumentError do
			@opts[:metric] = nil
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_allow_new_search
		assert_nothing_raised do
			MM::TromboneSearch.new(@opts)
		end
	end
	
	def test_trombone_search_should_prepare_search
		assert_nothing_raised do
			trombone_search = MM::TromboneSearch.new(@opts)
			trombone_search.send(:prepare_search)
		end
	end
	
	def test_trombone_search_should_get_candidate_list
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		assert(trombone_search.send(:get_candidate_list), ":get_candidate_list returned nil or false")
	end
	
	def test_trombone_search_parameters_to_ratio_should_require_narray_of_shape_2_2
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_raise ArgumentError do
			trombone_search.send(:parameters_to_ratio, NArray[[4,9]], "parameters_to_ratio accepted NArray of shape [2,1]")
		end
		assert_raise ArgumentError do
			trombone_search.send(:parameters_to_ratio, [[4, 9], [3, 1]], "parameters_to_ratio accepted Array")
		end
	end

	def test_trombone_search_should_convert_parameters_to_ratio
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_equal(HD::Ratio[4, 3], trombone_search.send(:parameters_to_ratio, NArray[[4, 9], [3, 1]]))
	end
	# Make sure the parameters_to_ratio function works on a vector of parameters
	def test_trombone_search_should_convert_parameter_vector_to_ratio_vector
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_equal(NArray[[4, 3], [16, 9]], trombone_search.send(:parameter_vector_to_ratio_vector, NArray[[[4, 9], [3, 1]], [[4, 9], [4, 1]]]))
	end
	
	def test_get_cost_should_accept_narray_of_2_2_4
		config = MM::DistConfig.new(:scale => :absolute, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => :abs_diff)
		@opts[:metric] = ->(a, b) do
			MM.dist_ucm(a, b, config)
		end
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_nothing_raised do
			trombone_search.send(:get_cost, NArray[[[4, 9], [3, 1]], [[4, 9], [2, 1]], [[4, 9], [4, 1]], [[4, 9], [1, 1]]])
		end
	end
end