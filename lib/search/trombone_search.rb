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
			ratio_vector = parameter_vector_to_ratio_vector candidate
			start_vector = parameter_vector_to_ratio_vector @start_vector
			# Judge these based on their distance from the goal vector
			(@metric.call(ratio_vector, start_vector) - @goal_vector).abs
		end
		
		# Gets a list of adjacent points
		# In this case it finds every possible partial of a given slide position
		def get_candidate_list
			point = @current_point.dup
			# Load it up with the possible permutations
			# old vector, which contained 65,536 permutations
			# harmonic_vector = (1..16).to_a.repeated_permutation(4)
			harmonic_vector = [-1, 0, 1].repeated_permutation(4)
			
			candidate_list = NArray.int(2, 2, 4, harmonic_vector.size)
			# We want to be able to sort and reject candidates
			# Note that this also works with nested loops, and it always iterates over the outermost dimension
			def candidate_list.each
				true_args = Array.new(self.dim-1, true)
				self.shape[-1].times do |i|
					yield self[*true_args, i]
				end
			end
			# Extending Enumerable so that we can use reject and sort and all the goodies
			candidate_list.extend Enumerable
			# Assign the point to every entry
			candidate_list[true, true, true, true] = point.newdim(3)
			# We want all adjacent ratios
			candidate_list[0, 1, true, true] += NArray.to_na(harmonic_vector.to_a)
			NArray.to_na(candidate_list.reject {|x| !(x[0, 1, true].all? {|y| y > 0})})
			# candidate_list
		end
		
		# Select a candidate based on best-first, offset by an index
		def get_candidate(candidate_list, index)
			# We want to return the first 3 dimensions of the item at a certain index
			candidate_list.sort do |c| 
				# Crazy hack, but required because we only want to override the #each method for the one object
				empty = NArray.int(*c.shape)
				true_array = *Array.new(empty.dim, true)
				empty[*true_array] = c[*true_array]
				get_cost empty
			end[true, true, true, index]
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