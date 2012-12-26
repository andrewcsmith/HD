require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'
require './get_angle.rb'
require 'nokogiri'
require './get_tuneable_data.rb'

# TODO: Fix this so that it works with the Angle object
module MM

  # This thing is going to be a massive OLM search function, on an x/y axis
  # The goal is to narrow in on a couple of coordinates, rather than just
  # distance
  @@get_olm_search = ->(opts) {
    
    # ===BASIC DEBUG SETTINGS
    # 0 = stop bothering me
    # 1 = general
    # 2 = lots more
    debug_level        = opts[:debug_level]        || 1
    
    start_vector       = opts[:start_vector]
    epsilon            = opts[:epsilon]            || 0.01
    max_iterations     = opts[:max_iterations]     || 1000

    # Added this so that we could get a custom list of tuneable intervals &
    # prime_weights in there
    hd_config          = opts[:hd_config]          || HD::HDConfig.new
    goal_vector        = opts[:goal_vector]

    tuneable_data      = opts[:tuneable_data]     || get_tuneable_data(NArray.to_na(start_vector), hd_config)
    banned_points      = opts[:banned_points]     || {}

    path = []
    # Load the list of tuneable intervals, reject the rejects
    hd_config.reject_untuneable_intervals!
    tuneable = hd_config.tuneable
    tuneable.sort_by! {|x| x.distance(HD.r, hd_config)}

    # Set the starting point for the first iteration
    current_point = start_vector
    # Generate a table of all possible costs
    # See 'get_tuneable_data.rb' for more info on the cost function
    current_cost = NMath.sqrt(((get_angle(current_point, start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
    
    # Initialize our bests to the current values
    best_point_so_far = current_point
    best_cost_so_far = current_cost
    
    # Add the start to the path as the first element
    path << start_vector
    
    # This matters for back-tracking
    initial_run = true
    # Decide how many of the "best" intervals to skip
    interval_index = 0
   
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
        
        # The cost vector is just a summation of all the possible movements
        cost = NMath.sqrt(((tuneable_data[true,1,true,true] - goal_vector) ** 2).sum(0))

        # If this is the first run-through, keep the interval index the same
        initial_run ? interval_index = 0 : false
      
        # Block tests for IndexError
        begin
          ind_x, ind_y = sort_by_cost(cost, interval_index)
          best_interval = tuneable_data[true,0,ind_x,ind_y]
          possible_interval = change_inner_interval(current_point, ind_y, HD.r(*best_interval))
          
          # Check to see whether the prospective point has beeen either banned
          # or is already in the current path (no infinite loop plz)
          # Note that banned_points is a hash, which facilitates extremely quick lookup. We don't care about the value, only whether or not there is a key.
          while (banned_points.has_key? HD.narray_to_string possible_interval) || (path.include? possible_interval)
            interval_index += 1
            # If we've exhausted all possible intervals, add it to the list of
            # banned points and step back
            if interval_index >= cost.size
              banned_points[HD.narray_to_string possible_interval] = 1
              bad = path.pop
              banned_points[HD.narray_to_string bad] = 1
              current_point = path[-1]
              initial_run = true
              current_cost = NMath.sqrt(((get_angle(path[-1], start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
              break
            end
            # Get the index of the movement that is at the current index level
            ind_x, ind_y = sort_by_cost(cost, interval_index)
            # Dereference that interval
            best_interval = tuneable_data[true,0,ind_x,ind_y]
            # Change the interval at that index to another interval, moving closer to the goal
            possible_interval = change_inner_interval(current_point,ind_y,HD.r(*best_interval))
          end
          
          # If the interval we just discovered is banned, move to the next index number. Otherwise, add it to the path.
          (banned_points.has_key? HD.narray_to_string possible_interval) ? next : (path << possible_interval)

        # Once in a while we will get an IndexError, when interval_index gets too large. This means that the current point needs to be rejected and added to the list of banned points, because every adjacent point that gets us closer is also bad.
        rescue IndexError => er
          puts "\nIndexError: #{er.message}"
          print er.backtrace.join("\n")
          banned_points[HD.narray_to_string path[-1]] = path[-1]
          path.pop
          current_point = path[-1]
          initial_run = true
          current_cost = NMath.sqrt(((get_angle(path[-1], start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
          next
        end
      
        (debug_level > 1) ? print "Trying interval #{HD.r(*best_interval)} at #{ind_y}" : false
        
        begin
          # TODO: Fix this to use an Angle object
          ang = get_angle(path[-1], start_vector, hd_config)
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
        ang = ang[0..1]
        ang = (ang - goal_vector) ** 2
        ang = ang.sum
        prospective_cost = NMath.sqrt(ang)
      
        # test to see if the prospective point gets us any closer
        if prospective_cost < current_cost
          current_cost = prospective_cost
        # if it only moves us back a little, give it a shot (after all, we'll
        # pick the best first soon) 
        # 
        # TODO: Compare the new not-that-bad cost to the cost of the path's
        # immediate predecessor. If picking the current result would be less
        # of a setback than popping and moving back a step, then just move
        # back a little – the next choice will be the best-first anyway.
        else
          # Calculate the cost of the one before the prospective choice
          previous_cost = NMath.sqrt(((get_angle(path[-2], start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
          if (prospective_cost - current_cost) < (prospective_cost - previous_cost)
            current_cost = prospective_cost
          else
            # if not, we don't want to move further away
            banned_points[HD.narray_to_string path[-1]] = path[-1]
            path.pop
            initial_run = false
            # puts "banning #{banned_points[-1].to_a}"
            next
          end
        end
   
        # if we're within a margin of tolerance, return
        if current_cost < epsilon
          current_point = path[-1]
          break
        else
          # Else, update the data table
          tuneable_data[true,1,true,true] += get_angle(current_point, start_vector, hd_config)[0..1]
          current_point = path[-1]
          if current_cost < best_cost_so_far
            best_point_so_far = current_point
            best_cost_so_far = current_cost
          end
          initial_run = true
        end
        if debug_level > 1
          puts "Now #{current_cost} away at #{current_point.to_a}"
        end
      end
    end
    # The data is passed back, for possible use in the next iteration of the search function. This makes it a little bit easier to find multiple points that are close to one another.
    data = {
      :tuneable_data => tuneable_data,
      :banned_points => banned_points,
      :cost => current_cost,
      :path => path
    }
    if current_cost > epsilon
      data[:failed] = true
      current_point = best_point_so_far
      current_cost = NMath.sqrt(((get_angle(current_point, start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
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

# Only run the stuff below if we're loading just this file
__FILE__ != $0 ? exit :

# Coordinates of Brooklyn
# 40.624722, -73.952222

f = File.open("./output_olm_search.txt", "w")

begin
  results = []

  hd_config = HD::HDConfig.new
  hd_config.prime_weights = [2.0,3.0,5.0,7.0,11.0]
  start_vector = HD::Ratio.from_s "1/1 2/1 3/2 2/3 16/9 32/27 8/3 2/1 3/1"

  opts = {}
  opts[:epsilon] = 0.44444444 / 28.0
  opts[:hd_config] = hd_config
  opts[:start_vector] = start_vector
  opts[:max_iterations] = 1000
  
  interval = 0.44444444444 / 14.0

  # This gives you the inverse
  looking_for_inverse = false
  looking_for_inverse ? angle += NMath::PI : false

  # Trying for #13 and #14 w-nw
  [0].each do |x|
    distance = 0.4126984126942857 + (x * interval)
    angle = (-73.952222 / 180.0) * NMath::PI
    ec = NMath.sin(angle) * distance
    hc = NMath.cos(angle) * distance
    
    # ACS: New for this test
    # ec = -0.04468230705093712
    # hc = 0.0037525148522866564
    # # Start is #12 w-nw
    # opts[:start_vector] = NArray[[1, 1], [1, 1], [8, 1], [20, 3], [160, 21], [40, 7], [320, 49], [240, 49], [160, 147]]
  
    opts[:goal_vector] = NArray[hc, ec]
    r = MM.get_olm_search.call(opts)
    results << [r[0]]
    results[-1] << MM.get_angle(results[-1][0], start_vector, hd_config)
    results[-1] << r[1]
    if r[1][:failed]
      f.print "\n\nFAILED with the following stats"
    end
    f.puts "\n\nRESULTS:\n#{results[-1][0].to_a}\n\n%.3f\t%.3f\t%.3f\t%.3f\t%.3f" % results[-1][1].to_a
    # f.puts "Goal Distance: #{distance}"
    f.puts "Cost: #{results[-1][2][:cost]}\n\n"
    opts[:tuneable_data] = r[1][:tuneable_data]
  end
  # 2.times do |t|
    # 12.upto(14) do |i|
    #   distance = interval * i
    #   hc = NMath.cos(angle) * distance
    #   ec = NMath.sin(angle) * distance
    #   opts[:goal_vector] = NArray[hc, ec] # This takes (y, x) for some stupid reason. Fix this.
    #   r = MM.get_olm_search.call(opts)
    #   results << [r[0]]
    #   results[-1] << MM.get_angle(results[-1][0], start_vector, hd_config)
    #   results[-1] << r[1]
    #   if r[1][:failed]
    #     f.print "\n\nFAILED with the following stats"
    #   end
    #   f.puts "\n\nRESULTS for #{i}:\n#{results[-1][0].to_a}\n\n%.3f\t%.3f\t%.3f\t%.3f\t%.3f" % results[-1][1].to_a
    #   f.puts "Goal Distance: #{distance}"
    #   f.puts "Cost: #{results[-1][2][:cost]}\n\n"
    #   opts[:tuneable_data] = r[1][:tuneable_data]
    # end
  #   angle += NMath::PI
  # end
ensure
  f.close
  # print results.to_a
end