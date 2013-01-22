require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'
require './get_angle.rb'
require './mm-angle.rb'
require './get_tuneable_data.rb'
require './hd_mm_addons.rb'

module MM

  # OLM search function, on an x/y axis
  @@get_olm_search = ->(opts) {

    # the starting point
    start_vector       = opts[:start_vector]

    # ===BASIC DEBUG SETTINGS
    # 0 = stop bothering me
    # 1 = general
    # 2 = lots more
    debug_level        = opts[:debug_level]        || 1
    # region of tolerance for acceptable results
    epsilon            = opts[:epsilon]            || 0.01
    # max iterations of the full loop
    max_iterations     = opts[:max_iterations]     || 1000

    # Added this so that we could get a custom list of tuneable intervals &
    # prime_weights in there
    hd_config          = opts[:hd_config]          || HD::HDConfig.new
    
    # end goal (2-dimensional vector) and an angle object to find that point
    goal_vector        = opts[:goal_vector]        || (raise ArgumentError, "opts[:goal_vector] required")
    angler             = opts[:angler]             || (raise ArgumentError, "opts[:angler] required")
    
    is_scaled          = opts[:is_scaled]         || false
    
    if is_scaled
      get_coords = angler.method(:get_scaled_coordinates_from_reference)
      get_angle = angler.method(:get_scaled_angle)
    else
      get_coords = angler.method(:get_coordinates_from_reference)
      get_angle = angler.method(:get_angle)
    end
    
    # Load the list of tuneable intervals, reject the rejects
    hd_config.reject_untuneable_intervals!
    hd_config.tuneable.sort_by! {|x| x.distance(HD.r, hd_config)}
    tuneable = hd_config.tuneable
    
    # Data that is returned by the proc, that can be re-passed to successive
    # searches to reduce load time. Otherwise, we populate it ourselves.
    # tuneable_data is an Array of all adjacent points and their coordinates
    tuneable_data      = opts[:tuneable_data]     || get_tuneable_data(NArray.to_na(start_vector), get_coords, hd_config)
    banned_points      = opts[:banned_points]     || {}
    
    lowest_old = []

    # path holds an array where each element is a successive vector in the
    # list of vectors that has been traversed thus far
    path = []

    # Set the starting point for the first iteration
    current_point = start_vector
      current_cost = NMath.sqrt(((get_coords.(current_point, start_vector) - goal_vector) ** 2).sum)
    
      # Initialize our bests to the current values
      best_point_so_far = current_point
      best_cost_so_far = current_cost
    
      # Add the start to the path as the first element
      path << start_vector
    
      # This matters for back-tracking
      initial_run = true
      # Decide how many of the "best" intervals to skip
      interval_index = 0
    
      catch :success do
        max_iterations.times do |iter|
          begin
            if debug_level > 1
              # Prints out a play-by-play
              puts "Iteration #{iter}"
              puts "Now #{current_cost} away at #{current_point.to_a}"
            end
            if debug_level > 0
              # Tells us where we are with each large-scale movement
              print "\rIteration #{iter}: #{current_cost} away at #{current_point.to_a}"
            end
            catch :keep_going do
            catch :jump_back do
              # Generate a table of all possible costs (see 'get_tuneable_data.rb' 
              # for more info on the cost function) 
              # The cost vector is just a summation of all the possible movements
              cost = NMath.sqrt(((tuneable_data - goal_vector) ** 2).sum(0))

              # If this is the first run-through, we want to start from the first 
              # interval
              initial_run ? (interval_index = 0; initial_run = false) : 0
      
              # Block tests for IndexError
              begin
                (interval_index >= cost.size) ? (throw :jump_back) : 0
                # Three lines initialize the point with the current interval_index
                ind_x, ind_y = sort_by_cost(cost, interval_index)
                possible_point = HD.change_inner_interval(current_point, ind_y, HD.r(*tuneable[ind_x]))
          
                while (banned_points.has_key? HD.narray_to_string possible_point) || (path.include? possible_point)
                  interval_index += 1
                  # If we've exhausted all possible intervals, add it to the list of
                  # banned points and step back
                  if interval_index >= cost.size
                    banned_points[HD.narray_to_string possible_point] = 1
                    initial_run = true
                    throw :jump_back
                  end
                  # Get the index of the movement that is at the current index level
                  ind_x, ind_y = sort_by_cost(cost, interval_index)
                  # Dereference that interval and assign the point
                  possible_point = HD.change_inner_interval(current_point, ind_y, HD.r(*tuneable[ind_x]))
                end
          
                # if the possible point is banned, don't add it
                (banned_points.has_key? HD.narray_to_string possible_point) ? (throw :jump_back) : (path << possible_point)

              # Once in a while we will get an IndexError, when interval_index gets
              # too large. This means that the current point needs to be rejected
              # and added to the list of banned points, because every adjacent point
              # that gets us closer is also bad.
              rescue IndexError => er
                puts "\nIndexError: #{er.message}"
                print er.backtrace.join("\n")
                initial_run = true
                throw :jump_back
              end
      
              (debug_level > 1) ? (print "Trying interval #{HD.r(*best_interval)} at #{ind_y}") : false
        
              begin
                current_coordinates = get_coords.(path[-1], start_vector)
              rescue RangeError => er
                puts "\nSeem to have a RangeError -- reordering"
                inner_v = vector_delta(path[-1], 1, get_inner_interval_delta(hd_config), MM::INTERVAL_FUNCTIONS[:pairs])
                # The following flips all the inner intervals of the second half of
                # the vector. This doesn't really change the outcome if the OLD is
                # properly used.
                ((inner_v.shape[1]/2)...inner_v.shape[1]).times do |x|
                  inner_v[true,x] = NArray[inner_v[true,x][1], inner_v[true,x][0]]
                end
                path[-1] = vector_from_differential inner_v
                puts "#{path[-1].to_a}"
                retry
              end

              # test to see if the prospective point gets us any closer
              prospective_cost = NMath.sqrt(((current_coordinates - goal_vector) ** 2).sum)
              (prospective_cost < current_cost) ? (current_cost = prospective_cost) : (throw :jump_back)
              # If we can't rearrange the vector to fit within the space move back
              # (MM.get_lowest_old(path[-1], start_vector)[0] == nil) ? (throw :jump_back) : 0
        
              # if we're within a margin of tolerance, success!
              if current_cost < epsilon
                current_point = path[-1]
                lowest_old = MM.get_lowest_old(current_point, start_vector)
                if debug_level > 0
                  puts "\nSuccess at: \t#{current_point.to_a}"
                  puts "Lowest OLD: \t#{lowest_old[0].to_a}"
                  puts "Angle: \t\t#{get_angle.(current_point, start_vector)}"
                  puts "Distance: \t#{NMath.sqrt((get_coords.(current_point) ** 2).sum)}"
                  puts "Cost: \t\t#{current_cost}"
                end
                # Return the loop and succeed
                throw :success
              else # Advance to next without jumping back
                throw :keep_going
              end
            end # catch [+:jump_back+]
            # Executed on :jump_back and with no "next" or "break"
            banned_points[HD.narray_to_string path[-1]] = path.pop
            current_point = path[-1] || (path << start_vector)[-1]
            current_cost = NMath.sqrt(((get_coords.(current_point, start_vector) - goal_vector) ** 2).sum)
            banned_points.delete HD.narray_to_string start_vector
            (debug_level > 1) ? (puts "banning #{banned_points[-1].to_a}") : false
          end # catch [+:keep_going+]
        rescue RuntimeError => e
          puts "\n#{e.message}"
          print e.backtrace.join("\n")
          print "\n\nPath: #{path.to_a}\n\n\n"
          break
        end # main iteration loop
      end
    end
    # The data is passed back, for possible use in the next iteration of the
    # search function. This makes it a little bit easier to find multiple
    # points from the same starting point (as it is not necessary to
    # re-populate tuneable_dataand banned_points)
    data = {
      :tuneable_data => tuneable_data,
      :banned_points => banned_points,
      :cost => current_cost,
      :lowest_old => lowest_old,
      :path => path
    }
    if current_cost > epsilon
      data[:failed] = true
      current_point = best_point_so_far
      current_cost = NMath.sqrt(((get_coords.(current_point, start_vector) - goal_vector) ** 2).sum)
    end
    [current_point, data] # Pass the tuneable_data back
  }
  
  # a syntactic shortcut
  [:get_olm_search].each do |sym|
    class_eval(<<-EOS, __FILE__, __LINE__)
      unless defined? @@#{sym}
        @@#{sym} = nil
      end

      def self.#{sym}
        @@#{sym}
      end

      def #{sym}
        @@#{sym}
      end
    EOS
  end
end

__FILE__ == $0 ? false : exit

# Implementation of the search function
# Coordinates of Brooklyn
# 40.624722, -73.952222

f = File.open("./results/olm_search " + Time.now.to_s + ".txt", "w")

begin
  results = []

  hd_config = HD::HDConfig.new
  hd_config.prime_weights = [2.0,3.0,5.0,7.0,11.0]
  # rejecting all intervals greater than two octaves and a fifth
  hd_config.tuneable.reject! {|x| x.to_f > 8.0}
  hd_config.reject_untuneable_intervals!
  start_vector = HD::Ratio.from_s "1/1 2/1 3/2 2/3 16/9 32/27 8/3 2/1 3/1"

  opts = {}
  interval = 0.44444444444 / 14.0
  opts[:epsilon] = interval / 2.0
  opts[:hd_config] = hd_config
  opts[:start_vector] = start_vector
  opts[:max_iterations] = 10000
  
  # Creating the angler
  lowest = NArray.int(2, start_vector.shape[1]).fill(1)
  x_bounds = [lowest, HD::Ratio.from_s("1/1 8/1 1/1 8/1 1/1 8/1 1/1 8/1 1/1")]
  y_bounds = [lowest, HD::Ratio.from_s("1/1 28/5 1/1 28/5 1/1 28/5 1/1 28/5 1/1")]
  x_cfg = MM::DistConfig.new({:scale => :none, :intra_delta => MM.get_ed_intra_delta, :inter_delta => MM::DELTA_FUNCTIONS[:longest_vector_abs_diff], :int_func => MM::INTERVAL_FUNCTIONS[:pairs]})
  y_cfg = MM::DistConfig.new({:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(hd_config), :inter_delta => MM::DELTA_FUNCTIONS[:longest_vector_abs_diff], :int_func => MM::INTERVAL_FUNCTIONS[:pairs]})
  angler = MM::Angle.new(MM.olm, MM.olm, x_bounds, x_cfg, y_bounds, y_cfg)
  opts[:angler] = angler
  opts[:is_scaled] = true
  
  (1..14).to_a.each do |x|
    # Finding the goal vector
    distance = x * interval
    angle = (-73.952222 / 180.0) * NMath::PI
    
    # This gives you the inverse
    looking_for_inverse = true
    looking_for_inverse ? (angle += NMath::PI) : false
    
    ec = NMath.sin(angle) * distance
    hc = NMath.cos(angle) * distance
    opts[:goal_vector] = NArray[ec, hc]
    
    r = MM.get_olm_search.call(opts)
    
    # results is an array where each element is:
    # [final vector, angle from origin, data dump]
    if results == -1
      next
    end
    results << [r[0]]
    results[-1] << angler.get_scaled_angle(results[-1][0], start_vector)
    results[-1] << r[1]
    lowest_old = MM.get_lowest_old(results[-1][0], start_vector)
    if r[1][:failed]
      f.print "\n\nFAILED with the following stats"
    end
    f.puts "\nRESULTS for #{x}:\n#{results[-1][0].to_a}"
    f.puts "Lowest OLD: #{results[-1][2][:lowest_old][0].to_a}"
    f.puts "Angle: \t#{results[-1][1]}"
    f.puts "Goal Distance: #{distance}"
    f.puts "Cost: #{results[-1][2][:cost]}\n\n"
    opts[:tuneable_data] = r[1][:tuneable_data]
  end
ensure
  f.close
  # print results.to_a
end