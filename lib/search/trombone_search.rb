# The beginnings of a search function to find pitches for a piece for trombones.
# 
# TODO:
# [ ] Override the necessary methods in MetricSearch:
#		 * :get_cost
#		 * :get_candidate_list
# 	 * :get_candidate
# [ ] Create an instance variable to allow the cost value of candidate_list to
#		 persist from iteration to iteration, so that we don't have to keep calling
#		 it over and over again.
# [ ] Each time the player hits the outer edge of the space, it should trigger a
#		 slide-position change. In addition, the frequency of slide changes should
#		 be measured and run through its own metrics. Perhaps this could impact the
#		 dynamic level, or the rhythm of the entrances, or the way the strings
#		 interact with the trombones, or some other parameter of the composition.
# 

module MM
	class TromboneSearch < MetricSearch
		def initialize opts = { }
			super opts
			if !@start_vector.is_a? NArray
				raise ArgumentError, ":start_vector must be NArray. You passed a #{@start_vector.class}."
			end
		end
		
		# Cost function for a candidate. This is where the meat is.
		def get_cost
			get_candidate_list
		end
		
		# Gets a list of adjacent points
		# In this case it finds every possible partial of a given slide position
		def get_candidate_list
			point = @current_point.dup
			# For now, this is a solo piece -- we assume that a point is just one pitch
			possible_points = NArray.int(2, 2, 16)
			possible_points[0, 1, true] = NArray.int(16).indgen(1)
			possible_points[1, 1, true] = 1
			# Iterate over this
			possible_points.shape[0].times do |i|
				possible_points[i, 0, true] = point[i, 0]
			end
		end
		
		# Select a candidate based on best-first
		def get_candidate(candidate_list, index)
			candidate_list.sort {|candidate| get_cost candidate}[index]
		end
	end
end