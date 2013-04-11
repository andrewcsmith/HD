require '../../Morphological-Metrics/mm.rb'
require 'test/unit'

class ComboTest < Test::Unit::TestCase
	include MM
	
	def setup
		# Example of a three-dimensional array where each element has shape == [2,3]
		@morph_array = NArray[[[4, 3], [5, 4], [3, 2]], [[2, 3], [4, 3], [6, 7]], [[7, 6], [8, 7], [11, 8]]]
		# Example of a two-dimensional array where each element is two integers
		@ratio_array = NArray[[3, 4], [2, 3], [5, 6]]
		# Example of a one-dimensional array where each element is a float
		@float_array = NArray[4.5, 2.3, 0, -3.2, 8]
	end

	# Makes sure the ordered_2_combinations method returns pairs
	# Each element is an NArray, where the last dimension is 2
	def test_ordered_2_combinations_should_return_pairs
		MM.ordered_2_combinations(@morph_array).each do |x|
			assert_equal(2, x.shape[-1])
		end
		MM.ordered_2_combinations(@ratio_array).each do |x|
			assert_equal(2, x.shape[-1])
		end
		MM.ordered_2_combinations(@float_array).each do |x|
			assert_equal(2, x.shape[-1])
		end
	end
	
	# Assert that every element in every pair is a Float
	def test_mapper_should_create_pairs_of_fixnums
		float_combos = MM.ordered_2_combinations(@float_array)
		MM::MAPPER_FUNCTIONS[:narray_pairs].call(float_combos) do |a, b|
			assert(a.is_a?(Float), "A is a #{a.class}")
			assert(b.is_a?(Float), "B is a #{b.class}")
		end
	end
	
	# Assert that every element in every pair is an NArray of dim 1
	def test_mapper_should_create_pairs_of_1_dim_narrays
		ratio_combos = MM.ordered_2_combinations(@ratio_array)
		MM::MAPPER_FUNCTIONS[:narray_pairs].call(ratio_combos) do |a, b|
			assert(a.is_a?(NArray) && a.dim == 1, "A is a #{a.class} of dim = #{a.dim}")
			assert(b.is_a?(NArray) && b.dim == 1, "B is a #{b.class} of dim = #{b.dim}")
		end
	end
	
	# Assert that every element in every pair is an NArray of dim 2
	def test_mapper_should_create_pairs_of_2_dim_narrays
		morph_combos = MM.ordered_2_combinations(@morph_array)
		MM::MAPPER_FUNCTIONS[:narray_pairs].call(morph_combos) do |a, b|
			assert(a.is_a?(NArray) && a.dim == 2, "A is a #{a.class} of dim = #{a.dim}")
			assert(b.is_a?(NArray) && b.dim == 2, "B is a #{b.class} of dim = #{b.dim}")
		end
	end
	
	# Asset that the output of mapper into the ordered_2_combinations is recursive
	def test_combinations_to_mapper_should_be_accepted_by_combinations
		morph_combos = MM.ordered_2_combinations(@morph_array)
		MM::MAPPER_FUNCTIONS[:narray_pairs].call(morph_combos) do |a, b|
			assert_nothing_raised do
				MM.ordered_2_combinations a
				MM.ordered_2_combinations b
			end
		end
	end
end