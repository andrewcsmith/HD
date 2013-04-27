require 'test/unit'
require_relative '../../hd-mm.rb'
require_relative '../../lib/search/trombone_search.rb'

class TromboneTest < Test::Unit::TestCase
	
	def setup
		start_vector = NArray[[[9, 16], [1, 1]], [[9, 16], [2, 1]], [[9, 16], [3, 1]], [[9, 16], [4, 1]]]
		# start_vector = NArray[[[4, 9], [1, 1]], [[5, 9], [1, 1]], [[7, 9], [1, 1]], [[1, 1], [1, 1]]]
		goal_vector = 0.5
    epsilon = 0.05
		metric = MM.ucm
		# For metric, we call 
		@opts = {:start_vector => start_vector, :epsilon => epsilon, :goal_vector => goal_vector, :metric => metric}
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
	
	def test_candidate_list_should_respond_to_sort
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		list = trombone_search.send(:get_candidate_list)
		assert(list.respond_to?(:sort))
    # puts list.sort.to_a.to_s
	end
	
	def test_candidate_list_should_have_enumerable_cycle_method
    trombone_search = MM::TromboneSearch.new(@opts)
    trombone_search.send(:prepare_search)
    list = trombone_search.send(:get_candidate_list)
    assert(list.respond_to?(:cycle), "#{list.inspect}")
	end
	
	# This will have to change if the definition of "adjacent point" changes
	def test_candidate_list_should_be_array_of_narrays_shape_2_2_4
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		list = trombone_search.send(:get_candidate_list)
    list.all? {|x| assert_equal([2, 2, 4], x.shape, ":get_candidate_list was the wrong shape") }
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
		# Instantiate a DistConfig that holds the proper intra_delta
		config = MM::DistConfig.new(:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => MM::DELTA_FUNCTIONS[:abs_diff])
		# Create a metric that takes this DistConfig
		# Using the closure features of a Proc to lock down the config variables
		@opts[:metric] = ->(a, b) do
			MM.dist_ucm(a, b, config)
		end
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_nothing_raised do
			begin
				trombone_search.send(:get_cost, NArray[[[4, 9], [3, 1]], [[4, 9], [2, 1]], [[4, 9], [4, 1]], [[4, 9], [1, 1]]])
				# If there is a problem, we want to print out the Exception, and re-raise so that the test fails
			rescue Exception => e
				puts e.message
				puts e.backtrace.join("\n")
				raise e
			end
		end
	end
	
	def test_get_candidate_should_return_a_single_candidate
		# Instantiate a DistConfig that holds the proper intra_delta
		config = MM::DistConfig.new(:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => MM::DELTA_FUNCTIONS[:abs_diff])
		@opts[:metric] = ->(a, b) { MM.dist_ucm(a, b, config) }
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		# Find the best candidate
		list = trombone_search.send(:get_candidate_list)
    # puts list.to_a.to_s
		candidate = trombone_search.send(:get_candidate, list, 0)
		assert(candidate)
		assert_equal([2,2,4], candidate.shape)
    # puts candidate.to_a.to_s
	end
	
	def test_search_should_find_a_point
		# Instantiate a DistConfig that holds the proper intra_delta
		config = MM::DistConfig.new :scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => MM::DELTA_FUNCTIONS[:abs_diff]
		@opts[:metric] = ->(a, b) { MM.dist_ucm(a, b, config) }
    # @opts[:goal_vector] = 0.5
    @opts[:debug_level] = 0
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_nothing_raised do
			begin
				results = trombone_search.search
        # puts "#{results[1][:path].inspect}"
        # puts "Cost: #{results[1][:cost].inspect}"
        # puts "Failed: #{results[1][:failed].inspect}"
			rescue Exception => e
				puts e.message
				puts e.backtrace.join("\n")
				raise e
			end
		end
	end
  
  # Should find every candidate that is in-range
  def test_get_slide_candidates_should_find_all_candidates
    trombone_search = MM::TromboneSearch.new(@opts)
    current_point = NArray[[[9, 16], [2, 1]], [[9, 16], [4, 1]], [[9, 16], [4, 1]], [[9, 16], [6, 1]]]
    desired_candidates = [NArray[[[9, 16], [2, 1]], [[3, 4], [3, 1]], [[9, 16], [4, 1]], [[9, 16], [6, 1]]], NArray[[[9, 16], [2, 1]], [[9, 16], [4, 1]], [[3, 4], [3, 1]], [[9, 16], [6, 1]]], NArray[[[9, 16], [2, 1]], [[9, 16], [4, 1]], [[9, 16], [4, 1]], [[27, 40], [5, 1]]]]
    received_candidates = trombone_search.send(:get_slide_candidates, current_point)
    # puts "#{received_candidates.inspect}"
    assert_equal(desired_candidates, received_candidates)
  end
  
  # Want to be sure that all candidates result in the same pitch content
  def test_slide_candidates_should_all_have_the_same_pitch
    trombone_search = MM::TromboneSearch.new(@opts)
    current_point = NArray[[[9, 16], [2, 1]], [[9, 16], [4, 1]], [[9, 16], [4, 1]], [[9, 16], [6, 1]]]
    candidates = trombone_search.send(:get_slide_candidates, current_point)
    candidates.each_cons(2) do |c|
      # Assert that each consective pair is equal in pitch content to the previous
      assert_equal(trombone_search.send(:parameter_vector_to_ratio_vector, c[0]), trombone_search.send(:parameter_vector_to_ratio_vector, c[1]))
    end
  end
  
  def test_should_choose_slide_candidate_with_least_effect_on_distance
    # Choose movement that moves the "chord" of slide positions the smallest
    # distance from its current position (using UCM, harmonic distance as
    # intra_delta)
    config = MM::DistConfig.new :scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => MM::DELTA_FUNCTIONS[:abs_diff]
    @opts[:metric] = ->(a, b) { MM.dist_ucm(a, b, config) }
    @opts[:debug_level] = 0
    trombone_search = MM::TromboneSearch.new(@opts)
    current_point = NArray[[[9, 16], [4, 1]], [[9, 16], [5, 1]], [[9, 16], [6, 1]], [[9, 16], [7, 1]]]
    trombone_search.instance_variable_set(:@current_point, current_point)
    # Assert that the current point has been properly set (as the search will not be prepared)
    assert_equal(trombone_search.instance_variable_get(:@current_point), current_point)
    # Get the top candidate
    candidates = trombone_search.send(:get_slide_candidates, current_point)
    winner = trombone_search.send(:choose_slide_candidate)
    winner_slide = winner[true, 0, true]
    current_slide = current_point[true, 0, true]
    winner_distance = @opts[:metric].call(winner_slide, current_slide)
    # puts "winner distance is #{winner_distance}"
    assert_block do
      candidates.all? do |c|
        c_slide = c[true, 0, true]
        d = @opts[:metric].call(c_slide, current_slide)
        # puts "other distance is #{d}"
        d >= winner_distance
      end
    end
  end
end