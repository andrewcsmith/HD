module MM
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
		# 
		# Outputs a 3-dimensional NArray of shape [2,j,i]
		# where j = the number of tuneable intervals
		# and i = the number of possible replacement points in the vector
		# for a vector of size n:
		# 	linear: i = n-1
		# 	combinatorial: i = (n**2/2) + n/2
		# 
		# dim1 holds the coordinate movement [x,y] in a 2-dimensional space from the origin
		# 
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
		# cost_vector is an NArray where each 
		def get_candidate_list
			NMath.sqrt(((@tuneable_data - @goal_vector) ** 2).sum(0))
		end
		# Gets a point from indices
		def get_candidate(candidate_list, interval_index)
			ind_x, ind_y = MM.sort_by_cost(candidate_list, interval_index)
			HD.change_inner_interval(@current_point, ind_y, HD.r(*@tuneable[ind_x]))
		end
		
		def prepare_search
			super
			@current_cost = get_cost(@get_coords.(@current_point, @start_vector), @goal_vector)
			@best_cost_so_far = @current_cost
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