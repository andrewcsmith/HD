# Refactoring the search functions into the following
# OLMSearch < MM::MetricSearch

module MM
	class MetricSearch
    attr_accessor :path
    def initialize opts
      # The following options should be common to all searches
			@start_vector				= opts[:start_vector]
			@debug_level				= opts[:debug_level]			|| 1
			@epsilon						= opts[:epsilon]					|| 0.01
			@max_iterations			= opts[:max_iterations]		|| 1000
			@goal_vector				= opts[:goal_vector]			|| (raise ArgumentError, "opts[:goal_vector] required")
		end
		
		def prepare_search
			@path = []
			@current_point = @start_vector
			@interval_index = 0
		end
		
		def get_cost_vector
			# Null for the dummy class
			# Must define in subclass
			raise "Must define :get_cost_vector in MM::MetricSearch"
		end
		
		def prepare_result
			# Null for the dummy class
			# Defining in subclass is optional
		end
		
		def debug_each_iteration iter
			case @debug_level
			when > 1 # Prints out a play-by-play
				puts "Iteration #{iter}"
				puts "Now #{@current_cost} away at #{@current_point.to_a}"
			when > 0
        # Tells us where we are with each large-scale movement
        print "\t\t\t\t\rIteration #{iter}: #{@current_cost} away at #{@current_point.to_a}"
			end
		end
		
		def prepare_each_run
			if @initial_run
				@interval_index = 0
				@initial_run = false
			end
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
									while (@banned_points.has_key? HD.narray_to_string possible_point) || (@path.include? possible_point)
										@interval_index += 1
										# If we've exhausted all possible intervals
										if @interval_index >= cost_vector.size
											@banned_points[HD.narray_to_string possible_point] = 1
											@initial_run = true
											throw :jump_back
										end
										# Get the index of the movement that is at the current index level
										possible_point = get_possible_point(@cost_vector, @interval_index)
									end
									if @banned_points.has_key? HD.narray_to_string possible_point
										throw :jump_back
									end
									@path << possible_point
									# When @interval_index gets too big, we may have an IndexError
								rescue IndexError => er
									puts "\nIndexError: #{er.message}"
									print er.backtrace.join("\n")
									initial_run = true
									throw :jump_back
								end
								
								begin
									current_coordinates = @get_coords.(@path[-1], @start_vector)
								rescue RangeError => er
									handle_range_error
									raise er
								end
								
								prospective_cost = get_cost(current_coordinates, @goal_vector)
								if prospective_cost < @current_cost
									@current_cost = prospective_cost
								else
									throw :jump_back
								end
								
								if @current_cost < @epsilon
									@current_point = @path[-1]
									prepare_result
	                throw :success
								else # Advance to the next without jumping back
									initial_run = true
									throw :keep_going
								end
							end # catch :jump_back
							@banned_points[HD.narray_to_string @path[-1]] = @path.pop
							@current_point = @path[-1] || (@path << @start_vector)[-1]
							@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
							@banned_points.delete HD.narray_to_string @start_vector
							if @debug_level > 1
								puts "banning #{@banned_points[-1].to_a}"
							end
						end # catch :keep_going
					rescue RuntimeError => er
						puts "\n#{er.message}"
						print er.backtrace.join("\n")
						print "\n\nPath: #{@path.to_a}\n\n\n"
						break
					end # RuntimeError block
				end # main iteration loop
			end # catch :success
			if debug_level > 0
				puts "\nSuccess at: \t#{@current_point.to_a}"
	      puts "Lowest OLD: \t#{@lowest_old[0].to_a}"
	      puts "Angle: \t\t#{@get_angle.(@current_point, @start_vector)}"
	      puts "Distance: \t#{get_cost(@get_coords.(@current_point), 0)}"
	      puts "Cost: \t\t#{@current_cost}"
			end
			@data = {
				:tuneable_data => @tuneable_data,
				:banned_points => @banned_points,
				:cost => @current_cost,
				:lowest_old => @lowest_old,
				:path => @path
			}
			if @current_cost > @epsilon
				@data[:failed] = true
				@current_point = @best_point_so_far
				@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
			[@current_point, @data]
		end
	end
  
	class OLMSearch < MetricSearch
		attr_accessor :tuneable
    
		def initialize opts
			super opts
			@hd_config					= opts[:hd_config]				|| HD::HDConfig.new
      @angler							= opts[:angler]						|| (raise ArgumentError, "opts[:angler] required")
      @is_scaled?					= opts[:is_scaled]				|| false
			@tuning_range				= opts[:tuning_range]			|| [HD.r(2,3), HD.r(16,1)]
      # Reference methods from the angler
			if is_scaled?
				@get_coords = angler.method(:get_scaled_coordinates_from_reference)
				@get_angle = angler.method(:get_scaled_angle)
			else
				@get_coords = angler.method(:get_coordinates_from_reference)
				@get_angle = angler.method(:get_angle)
			end
			# Load list of tuneable intervals, reject those that won't work
			@hd_config.reject_untuneable_intervals!
			# Sort intervals by harmonic distance
			@hd_config.tuneable.sort_by! {|x| x.distance(HD.r, hd_config)}
			@tuneable = hd_config.tuneable
      
			@debug_level > 0 ? (print "\n== Getting tuneable data...") : false
	    @tuneable_data			= opts[:tuneable_data]		|| get_tuneable_data(NArray.to_na(start_vector), get_coords, hd_config)
	    @debug_level > 0 ? (puts "done.") : false
	    @banned_points			= opts[:banned_points]		|| {}
			
			@lowest_old = []
    end
		
		def prepare_search
			super
			@path = []
			@current_cost = get_cost(@get_coords.(@current_point, @start_vector), goal_vector)
			@best_point_so_far = @current_point
			@best_cost_so_far = @current_cost
			@path << @start_vector
			@initial_run = true
		end
		
		# Makes sure that the current point is satisfactory
		def prepare_result
			@lowest_old = MM.get_lowest_old(@current_point, @start_vector, @hd_config, false, @tuning_range)
      if @lowest_old[0] == nil
				@initial_run = true
				throw :jump_back
			end
		end
		
		def search
			interval_index = 0
			catch :success do
				@max_iterations.times do |iter|
					begin # RuntimeError block
						
						case @debug_level
						when > 1 # Prints out a play-by-play
							puts "Iteration #{iter}"
							puts "Now #{@current_cost} away at #{@current_point.to_a}"
						when > 0
	            # Tells us where we are with each large-scale movement
	            print "\t\t\t\t\rIteration #{iter}: #{@current_cost} away at #{current_point.to_a}"
						end
						catch :keep_going do
							catch :jump_back do
								# Generate a table of all possible costs
								# Cost vector is summation of all possible movements
								cost = NMath.sqrt(((@tuneable_data - @goal_vector) ** 2).sum(0))
								if initial_run
									interval_index = 0
									initial_run = false
								end
								begin # IndexError block
									if interval_index >= cost.size
										throw :jump_back
									end
									possible_point = get_possible_point(cost, interval_index
									while (banned_points.has_key? HD.narray_to_string possible point) || (path.include? possible_point)
										interval_index += 1
										# If we've exhausted all possible intervals
										if interval_index >= cost.size
											banned_points[HD.narray_to_string possible_point] = 1
											initial_run = true
											throw :jump_back
										end
										# Get the index of the movement that is at the current index level
										possible_point = get_possible_point(cost, interval_index)
									end
									(@banned_points.has_key? HD.narray_to_string possible_point)
								rescue IndexError => er
									puts "\nIndexError: #{er.message}"
									print er.backtrace.join("\n")
									initial_run = true
									throw :jump_back
								end
								
								begin
									current_coordinates = get_coords.(path[-1], start_vector)
								rescue RangeError => er
									puts "\nSeem to have a RangeError -- reordering"
									inner_v = vector_delta(@path[-1], 1, get_inner_interval_delta(@hd_config), INTERVAL_FUNCTIONS[:pairs])
	                ((inner_v.shape[1]/2)...inner_v.shape[1]).times do |x|
	                  inner_v[true,x] = NArray[inner_v[true,x][1], inner_v[true,x][0]]
	                end
	                path[-1] = vector_from_differential inner_v
	                puts "#{path[-1].to_a}"
	                retry
								end
								
								prospective_cost = get_cost(current_coordinates, goal_vector)
								if prospective_cost < @current_cost
									@current_cost = prospective_cost
								else
									throw :jump_back
								end
								
								if @current_cost < @epsilon
									@current_point = @path[-1]
									@lowest_old = MM.get_lowest_old(@current_point, @start_vector, @hd_config, false, @tuning_range)
	                if @lowest_old[0] == nil
										initial_run = true
										throw :jump_back
									end
	                throw :success
								else # Advance to the next without jumping back
									initial_run = true
									throw :keep_going
								end
							end # catch :jump_back
							@banned_points[HD.narray_to_string @path[-1]] = @path.pop
							@current_point = @path[-1] || (@path << @start_vector)[-1]
							@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
							@banned_points.delete HD.narray_to_string @start_vector
							if @debug_level > 1
								puts "banning #{@banned_points[-1].to_a}"
							end
						end # catch :keep_going
					rescue RuntimeError => er
						puts "\n#{er.message}"
						print er.backtrace.join("\n")
						print "\n\nPath: #{@path.to_a}\n\n\n"
						break
					end # RuntimeError block
				end # main iteration loop
			end # catch :success
			if debug_level > 0
				puts "\nSuccess at: \t#{@current_point.to_a}"
	      puts "Lowest OLD: \t#{@lowest_old[0].to_a}"
	      puts "Angle: \t\t#{@get_angle.(@current_point, @start_vector)}"
	      puts "Distance: \t#{get_cost(@get_coords.(@current_point), 0)}"
	      puts "Cost: \t\t#{@current_cost}"
			end
			@data = {
				:tuneable_data => @tuneable_data,
				:banned_points => @banned_points,
				:cost => @current_cost,
				:lowest_old => @lowest_old,
				:path => @path
			}
			if @current_cost > @epsilon
				@data[:failed] = true
				@current_point = @best_point_so_far
				@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
			[@current_point, @data]
		end
		
		####################
		## HELPER METHODS ##
		####################
		# Fills in the cost vector
		def get_cost_vector
			NMath.sqrt(((@tuneable_data - @goal_vector) ** 2).sum(0))
		end
		# Gets a point from indices
		def get_possible_point(cost, interval_index)
			ind_x, ind_y = sort_by_cost(cost, interval_index)
			possible_point = HD.change_inner_interval(@current_point, ind_y, HD.r(*@tuneable[ind_x]))
			possible_point
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
      retry
		end
		# Cost function for this method
		def get_cost(current_coordinates, goal_vector)
			NMath.sqrt(((current_coordinates - goal_vector) ** 2).sum)
		end
  end
end