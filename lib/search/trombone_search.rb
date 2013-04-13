# The beginnings of a search function to find pitches for a piece for trombones.
# 
# TODO:
# [ ] Override the necessary methods in MetricSearch:
#		 * :get_cost
#		 * :get_candidate_list
# [ ] Create an instance variable to allow the cost value of candidate_list to
#		 persist from iteration to iteration, so that we don't have to keep calling
#		 it over and over again.
# [ ] Each time the player hits the outer edge of the space, it should trigger a
#		 slide-position change. In addition, the frequency of slide changes should
#		 be measured and run through its own metrics. Perhaps this could impact the
#		 dynamic level, or the rhythm of the entrances, or the way the strings
#		 interact with the trombones, or some other parameter of the composition.
# 
# 

module MM
	class TromboneSearch < MetricSearch
		
	end
end