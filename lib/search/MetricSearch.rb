# Refactoring the search functions into the following
# OLMSearch < MM::MetricSearch

module MM
	class MetricSearch
    attr_accessor :path
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
			prepare_search
			catch :success do
				# Main iteration loop
				@max_iterations.times do |iter|
					begin # RuntimeError block
						debug_each_iteration iter
						catch :keep_going do
							catch :jump_back do
								prepare_each_run
								# Cost vector is summation of all possible movements
								cost_vector = get_cost_vector
								begin # IndexError block
									if @interval_index >= cost_vector.size
										throw :jump_back
									end
									possible_point = get_possible_point(cost_vector, @interval_index)
									while (@banned_points.has_key? possible_point.hash) || (@path.include? possible_point)
										@interval_index += 1
										# If we've exhausted all possible intervals
										if @interval_index >= cost_vector.size
											@banned_points[possible_point.hash] = 1
											@initial_run = true
											throw :jump_back
										end
										# Get the index of the movement that is at the current index level
										possible_point = get_possible_point(cost_vector, @interval_index)
									end
<<<<<<< Local Changes
<<<<<<< Local Changes
									@banned_points.has_key? possible_point.hash ? throw(:jump_back) : @path
									end
									@path << possible_point
=======
									if @banned_points.has_key? possible_point.hash
										throw :jump_back
									end
									@path << possible_point
>>>>>>> External Changes
=======
									if @banned_points.has_key? possible_point.hash
										throw :jump_back
									end
									@path << possible_point
>>>>>>> External Changes
									# When @interval_index gets too big, we may have an IndexError
								rescue IndexError => er
									puts "\nIndexError: #{er.message}"
									print er.backtrace.join("\n")
									initial_run = true
									throw :jump_back
								end
								# Find coordinates of the current point
								begin
									current_coordinates = @get_coords.(@path[-1], @start_vector)
								rescue RangeError => er
									handle_range_error(er) ? retry : (raise er)
								end
								# Find the cost of the prospective point
								prospective_cost = get_cost(current_coordinates, @goal_vector)
								if prospective_cost < @current_cost
									@current_cost = prospective_cost
								else
									throw :jump_back
								end
								# If the current cost is less than the goal, success!
								if @current_cost < @epsilon
									@current_point = @path[-1]
									prepare_result
	                throw :success
								else # Otherwise, advance to the next iteration without jumping back
									initial_run = true
									throw :keep_going
								end
							end # catch :jump_back
							jump_back
						end # catch :keep_going
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
			@interval_index = 0
			@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
			@best_point_so_far = @current_point
			@best_cost_so_far = @current_cost
			@path = [@start_vector]
			@initial_run = true
		end
		
		def get_cost
			# Null for the dummy class
			raise "Must define :get_cost in subclass of MM::MetricSearch"
		end
		
		def get_cost_vector
			# Null for the dummy class
			# Must define in subclass
			raise "Must define :get_cost_vector in subclass of MM::MetricSearch"
		end
		
		# Gets a point from indices
		def get_possible_point(cost, interval_index)
			ind_x, ind_y = MM.sort_by_cost(cost, @interval_index)
			HD.change_inner_interval(@current_point, ind_y, HD.r(*@tuneable[ind_x]))
		end
		
		def prepare_result
			# Null for the dummy class
			# Defining in subclass is optional
		end
		
		def handle_range_error er
			# Dummy method
		end
		
		def debug_each_iteration iter
			case 
			when @debug_level > 1 # Prints out a play-by-play
				puts "Iteration #{iter}"
				puts "Now #{@current_cost} away at #{@current_point.to_a}"
			when @debug_level > 0
        # Tells us where we are with each large-scale movement
        print "\t\t\t\t\rIteration #{iter}: #{@current_cost} away at #{@current_point.to_a}"
			end
		end
		
		def debug_final_report
			case 
			when @debug_level > 0
				puts "\nSuccess at: \t#{@current_point.to_a}"
	      puts "Distance: \t#{get_cost(@get_coords.(@current_point), 0)}"
	      puts "Cost: \t\t#{@current_cost}"
			end
		end
		
		def jump_back
			@banned_points[@path[-1].hash] = @path.pop
			@current_point = @path[-1] || (@path << @start_vector)[-1]
			@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
			@banned_points.delete @start_vector.hash
			if @debug_level > 1
				puts "banning #{@banned_points[-1].to_a}"
			end
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
				@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
			end
		end
	end
  
	class OLMSearch < MetricSearch
		attr_accessor :tuneable, :goal_vector, :start_vector
    
		def initialize opts
			super opts
			@hd_config					= opts[:hd_config]				|| HD::HDConfig.new
      @angler							= opts[:angler]						|| (raise ArgumentError, "opts[:angler] required")
      @is_scaled					= opts[:is_scaled]				|| false
			@tuning_range				= opts[:tuning_range]			|| [HD.r(2,3), HD.r(16,1)]
      # Reference methods from the angler
			if @is_scaled
				@get_coords 			= @angler.method(:get_scaled_coordinates_from_reference)
				@get_angle 				= @angler.method(:get_scaled_angle)
			else
				@get_coords 			= @angler.method(:get_coordinates_from_reference)
				@get_angle 				= @angler.method(:get_angle)
			end
			# Load list of tuneable intervals, reject those that won't work
			@hd_config.reject_untuneable_intervals!
			# Sort intervals by harmonic distance
			@hd_config.tuneable.sort_by! {|x| x.distance(HD.r, @hd_config)}
			@tuneable = @hd_config.tuneable
      
			@debug_level > 0 ? (print "\n== Getting tuneable data...") : false
	    @tuneable_data			= opts[:tuneable_data]		|| get_tuneable_data(NArray.to_na(@start_vector), @get_coords, @hd_config)
	    @debug_level > 0 ? (puts "done.") : false
			@lowest_old = []
    end
		
		####################
		## HELPER METHODS ##
		####################
		# Tuneable data method
	  def get_tuneable_data(origin, get_coords, hd_config)
	    # Initialize an empty NArray with all data
	    tuneable_data = NArray.float(2, hd_config.tuneable.size, origin.shape[1]-1)
	    # TODO: Vectorize these loops!
	    # Iterate through each first differential index
	    # i = index of the first differential
	    tuneable_data.shape[2].times do |i| 
	      # Iterate through each tuneable interval
	      # j = index of each tuneable interval
	      tuneable_data.shape[1].times do |j|
	        begin
	          # find the first differential of the vector
	          vector_delta = (MM.vector_delta(origin, 1, MM::DELTA_FUNCTIONS[:hd_ratio], MM::INTERVAL_FUNCTIONS[:pairs])).dup
	          # switch out each of the intervals in the first differential with
	          # one of the tuneable intervals
	          vector_delta[true,i] = hd_config.tuneable[j]
	          # log how the vector moved from the origin
	          tuneable_data[true,j,i] = get_coords.(MM.vector_from_differential(vector_delta), origin)
	        # rescue
	        #   puts "index #{j}, #{i} didn't seem to work"
	        end
	      end
	    end
	    tuneable_data 
	  end
		# Cost function for this method
		def get_cost(current_coordinates, goal_vector)
			NMath.sqrt(((current_coordinates - goal_vector) ** 2).sum)
		end
		# Fills in the cost vector
		def get_cost_vector
			NMath.sqrt(((@tuneable_data - @goal_vector) ** 2).sum(0))
		end
		# Takes care of the RangeError and retries
		def handle_range_error
			puts "\nSeem to have a RangeError -- reordering"
			inner_v = vector_delta(@path[-1], 1, get_inner_interval_delta(@hd_config), INTERVAL_FUNCTIONS[:pairs])
      ((inner_v.shape[1]/2)...inner_v.shape[1]).times do |x|
        inner_v[true,x] = NArray[inner_v[true,x][1], inner_v[true,x][0]]
      end
      @path[-1] = vector_from_differential inner_v
      puts "#{@path[-1].to_a}"
      true # Error handled
		end
		# Makes sure that the current point is satisfactory
		def prepare_result
			super
			@lowest_old = MM.get_lowest_old(@current_point, @start_vector, @hd_config, false, @tuning_range)
      if @lowest_old[0] == nil
				@initial_run = true
				throw :jump_back
			end
		end
		# Prepare the final data report, specific to OLM tuning
		def prepare_data
			super
			@data[:tuneable_data] = @tuneable_data
			@data[:@lowest_old] = @lowest_old
		end
		# Send the final report
		def debug_final_report
			super
			if @debug_level > 0
	      puts "Lowest OLD: \t#{@lowest_old[0].to_a}"
	      puts "Angle: \t\t#{@get_angle.(@current_point, @start_vector)}"
			end
		end
  end
end