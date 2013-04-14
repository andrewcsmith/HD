require 'test/unit'
require_relative '../hd-mm.rb'

class MetricNestingTest < Test::Unit::TestCase
	def setup
		# Example of a three-dimensional array where each element has shape == [2,3]
		@morph_vector = NArray[[[4, 3], [5, 4], [3, 2]], [[2, 3], [4, 3], [6, 7]], [[7, 6], [8, 7], [11, 8]]]
		@morph_vector_compare = NArray[[[4, 3], [5, 4], [7, 5]], [[6, 5], [11, 4], [11, 7]], [[9, 8], [10, 9], [5, 4]]]
		# Example of a two-dimensional array where each element is two integers
		@ratio_vector = NArray[[3, 4], [2, 3], [5, 6]]
		@ratio_vector_compare = NArray[[4, 3], [5, 4], [7, 5]]
		# Example of a one-dimensional array where each element is a float
		@float_vector = NArray[4.5, 2.3, 0, -3.2, 8]
		@float_vector_compare = NArray[3.4, 3.2, 7.4, 1, 2.8]
	end
	
	def test_ucm_as_intra_delta
		# MM.dist_ocm(@morph_vector, @morph_vector_compare, config)
		# - using the UCM as the intra_delta
		# 	- using the HD-function as intra_delta
		# 	- using abs_diff as inter_delta
		# - using abs_diff as inter_delta
		# 
		# First create the UCM proc to use as the intra_delta
		dist_ucm_config = MM::DistConfig.new(:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new))
		dist_ucm = ->(a, b){MM.dist_ucm(a, b, dist_ucm_config)}
		# Next, create the OCM config using the UCM as the intra_delta (all else is default)
		dist_ocm_config = MM::DistConfig.new(:scale => :none, :intra_delta => dist_ucm)
		
		# Template to assert that every one of the elements is correct
		assert_element = ->(result, vector, location) do
			assert_in_delta(result, MM.dist_ucm(vector[true,true,location[0]], vector[true,true,location[1]], dist_ucm_config), 0.001)
		end
		# ucm_vector should = [ 1.67638, 4.77817, 6.45455 ]
		# ucm_vector_compare should = [ 0.091669, 0.249597, 0.341266 ]
		assert_element.call(1.67638, @morph_vector, [0,1])
		assert_element.call(4.77817, @morph_vector, [0,2])
		assert_element.call(6.45455, @morph_vector, [1,2])
		assert_element.call(0.091669, @morph_vector_compare, [0,1])
		assert_element.call(0.249597, @morph_vector_compare, [0,2])
		assert_element.call(0.341266, @morph_vector_compare, [1,2])
		# ocm should = 3.0190468232722165
		assert_in_delta(4.0755, MM.dist_ocm(@morph_vector, @morph_vector_compare, dist_ocm_config), 0.001)
	end
	
	# def test_ucm_as_inter_delta
	# 	# Work these out by hand
	# end
end