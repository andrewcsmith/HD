require '../../hd-mm.rb'
require '../../lib/search/trombone_search.rb'
require 'test/unit'

class TromboneTest < Test::Unit::TestCase
	
	def setup
		
	end
	
	def test_trombone_search_should_require_start_vector_narray
		assert_raise(ArgumentError) do
			MM::TromboneSearch.new(:start_vector => [[4, 9], [3, 1]])
		end
	end
	def test_trombone_search_should_require_goal_vector
		assert_raise(ArgumentError) do
			MM::TromboneSearch.new(:start_vector => NArray[[4, 9], [3, 1]])
		end
	end
	def test_trombone_search_should_allow_new_search
		assert_nothing_raised do
			MM::TromboneSearch.new(:start_vector => NArray[[4, 9], [3, 1]], :goal_vector => 0.458)
		end
	end
	
	def test_trombone_search_should_prepare_search
		
	end
end