# Refactoring the search functions into the following
# OLMSearch < MM::MetricSearch

module MM
	# Performs a gradient descent search using one of the morphological metrics in MM
	# This is a search in 2-dimensional Euclidean space
	class MetricSearch
		attr_accessor :path, :goal_vector, :start_vector, :current_point, :debug_level
		
		def initialize opts = {}
			# The following options should be common to all searches
			@start_vector				= opts[:start_vector]			|| (raise ArgumentError, "opts[:start_vector] required")
			@debug_level				= opts[:debug_level]			|| 1
			@epsilon						= opts[:epsilon]					|| 0.01
			@max_iterations			= opts[:max_iterations]		|| 1000
			@goal_vector				= opts[:goal_vector]			|| (raise ArgumentError, "opts[:goal_vector] required")
			@banned_points			= opts[:banned_points]		|| {}
		end
		
		def search
			# Only need to do this once per search
			prepare_search
			catch :success do
				# Main iteration loop
				@max_iterations.times do |iter|
					begin # RuntimeError block
						# anything that needs to be done at the start of each iteration
						prepare_each_run
						if @banned_points.has_key?(path[-1]) && path.size == 1
							throw :success
						end
						# any log messages that are printed at the start of each iteration
						debug_each_iteration iter
						going = catch :keep_going do
							m = catch :jump_back do
								# cost_vector is a list of all adjacent points with their respective costs
								candidate_list = get_candidate_list
								begin # IndexError block
									# if we've run out of all possible points, step back and keep trying
                  # NOTE: This only works when candidate_list#size is the largest dimension
                  # i.e., for a normal Array of NArrays. For NArray, #size gives the total
                  # number of elements.
									@interval_index >= candidate_list.size ? throw(:jump_back, "Interval Index too large ln. 43") : false
									# load up the candidate from our cost_vector
									candidate = get_candidate(candidate_list, @interval_index)
                  prospective_cost = @current_cost
									# skip all candidates that are banned or already in the path or don't get us any closer
									while (@banned_points.has_key? candidate.hash) || (@path.include? candidate) || (prospective_cost >= @current_cost)
										@interval_index += 1
										# If we've exhausted all possible intervals, jump back
										if @interval_index >= candidate_list.size
											@banned_points[candidate.hash] = 1
											throw :jump_back, "Interval Index #{@interval_index} too large ln 54"
										end
										# Get the movement # that is at the current index
										candidate = get_candidate(candidate_list, @interval_index)
                    prospective_cost = get_prospective_cost candidate
									end
                  # Add it to the path!
                  @path << candidate
								# When @interval_index gets too big, we may have an IndexError
								# This should be avoided by the first line of the IndexError block
								rescue IndexError => er
									puts "\nIndexError: #{er.message}"
									print er.backtrace.join("\n")
									# Rescue and print the error, then jump back
									throw :jump_back, "Index error"
                rescue RangeError => er
									# If handle_range_error has not been defined in a subclass, any call will just
									# re-raise the exception
                  handle_range_error(er) ? retry : (raise er)
								end
								# If the current cost is less than the goal, success!
								if @current_cost < @epsilon
									@current_point = @path[-1]
									prepare_result
									throw :success
								else # Otherwise, advance to the next iteration without jumping back
									@initial_run = true
									throw :keep_going, true
								end
							end # catch :jump_back
              if @debug_level > 1
                puts m
              end
							jump_back
						end # catch :keep_going
            if going
              keep_going
              going = false
            end
					rescue RuntimeError => er
						puts "\n#{er.message}"
						print er.backtrace.join("\n")
						print "\n\nPath: #{@path.to_a}\n\n\n"
						break
					end # RuntimeError block
				end # main iteration loop
			end # catch :success
			debug_final_report
			prepare_data
			[@current_point, @data]
		end
		
		def prepare_search
			@current_point = @start_vector
			@best_point_so_far = @current_point
			@interval_index = 0
			@path = [@start_vector]
			@initial_run = true

			# These will used the overriden get_cost methods
			begin
				@current_cost = get_cost @current_point
				@best_cost_so_far = @current_cost
			rescue
				# If this is called, then the @current_cost is not set
			end
		end
		
		# Finds the cost of a given possible point
		def get_cost candidate
			# Null for the dummy class
			raise "Must define :get_cost in subclass of MM::MetricSearch"
		end
		
		def get_prospective_cost candidate
			get_cost candidate
		end
		
		def get_candidate_list
			# Null for the dummy class
			# Must define in subclass
			raise "Must define :get_candidate_list in subclass of MM::MetricSearch"
		end
		
		# Gets a point from indices
		def get_candidate(candidate_list, interval_index)
			# Null for the dummy class
			# Must define in subclass
			raise "Must define :get_candidate in subclass of MM::MetricSearch"
		end
		
		def prepare_result
			# Null for the dummy class
			# Defining in subclass is optional
		end
		
		def handle_range_error er
			# Dummy method
			false
		end
		
		def debug_each_iteration iter
			case 
			when @debug_level > 1 # Prints out a play-by-play
				puts "Iteration #{iter}"
				puts "Now #{@current_cost} away at #{@current_point.inspect}"
			when @debug_level > 0
				# Tells us where we are with each large-scale movement
				print "\t\t\t\t\rIteration #{iter}: #{@current_cost} away at #{@current_point.inspect}"
			end
		end
		
		def debug_final_report
			case 
			when @debug_level > 0
				puts "\nSuccess at: \t#{@current_point.to_a}"
				puts "Distance: \t#{get_cost @current_point}"
				puts "Cost: \t\t#{@current_cost}"
			end
		end
		
		def jump_back
			@banned_points[@path[-1].hash] = @path.pop
			@current_point = @path[-1] || (@path << @start_vector)[-1]
			@current_cost = get_cost @current_point
			@banned_points.delete @start_vector.hash
      @initial_run = true
			if @debug_level > 1
        puts "jumping back!"
				puts "banning #{@banned_points[-1].inspect}"
			end
		end
    
    def keep_going
      # To be subclassed
    end
		
		def prepare_each_run
			if @initial_run
				@interval_index = 0
				@initial_run = false
			end
		end
		
		def prepare_data
			@data = {
				:banned_points => @banned_points,
				:cost => @current_cost,
				:path => @path
			}
			if @current_cost > @epsilon
				@data[:failed] = true
				@current_point = @best_point_so_far
				# @current_cost = get_cost @get_coords.(@current_point, @start_vector)
			end
		end
	end
end
