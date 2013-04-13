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
		attr_accessor :start_vector, :current_point
		
		def initialize opts = { }
			super opts
			if !@start_vector.is_a? NArray
				raise ArgumentError, ":start_vector must be NArray. You passed a #{@start_vector.class}."
			elsif @start_vector.shape != [2,2,4]
				raise ArgumentError, ":start_vector must be shape [2,2,4]. You passed #{@start_vector.shape.to_a}"
			end
			@metric = opts[:metric] || raise(ArgumentError, "please provide a metric to TromboneSearch")
		end
		
		def prepare_search
			super
		end
		
		# Cost function for a candidate. This is where the magic happens.
		def get_cost candidate
			# Convert the candidate into a string of ratios to call it with our Morphological Metric
			ratio_vector = NArray.int(2, candidate.shape[-1])
			candidate.shape[-1].times do |i|
				ratio_vector[true, i] = parameters_to_ratio(candidate[true, true, i])
			end
			@metric.call(ratio_vector, @start_vector)
		end
		
		# Gets a list of adjacent points
		# In this case it finds every possible partial of a given slide position
		def get_candidate_list
			point = @current_point.dup
			# For now, we assume that a "point" is just a single 4-voice chord
			candidate_list = NArray.int(2, 2, 4, 16)
			# Iterate over each voice
			candidate_list.shape[2].times do |j|
				candidate_list[0, 1, j, true] = NArray.int(16).indgen(1)
				candidate_list[1, 1, j, true] = 1
				# Iterate over each ratio
				candidate_list.shape[0].times do |i|
					candidate_list[i, 0, j, true] = point[i, 0, j]
				end
			end
			candidate_list
		end
		
		# Select a candidate based on best-first
		def get_candidate(candidate_list, index)
			candidate_list.sort {|candidate| get_cost candidate}[index]
		end
		
		# ================ #
		# HELPER FUNCTIONS #
		# ================ #
		
		def parameters_to_ratio p
			# Validate argument
			if !p.is_a?(NArray) || p.shape != [2,2]
				raise ArgumentError, "parameters_to_ratio only accepts NArray of shape [2, 2]. You passed #{p.inspect}"
			end
			# Multiply the dimensions together to get the ratio
			p = HD::Ratio[*p[true, 0]] * HD::Ratio[*p[true, 1]]
			p
		end
		
		def parameter_vector_to_ratio_vector p
			# Validate argument
			if !p.is_a?(NArray) || p.shape[0..1] != [2,2] || p.dim != 3
				raise ArgumentError, "parameter_vector_to_ratio_vector only accepts 3-dimensional NArrays of shape [2, 2, n]"
			end
			ratio_vector = NArray.int(2, p.shape[2])
			p.shape[2].times do |i|
				ratio_vector[true, i] = parameters_to_ratio(p[true, true, i])
			end
			ratio_vector
		end
	end
end