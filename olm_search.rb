require './hd.rb'
require '../Morphological-Metrics/mm.rb'
require './deltas.rb'
require './get_angle.rb'
require 'nokogiri'
require './get_tuneable_data.rb'

module MM

  # This thing is going to be a massive OLM search function, on an x/y axis
  # The goal is to narrow in on a couple of coordinates, rather than just distance
  @@get_olm_search = ->(opts) {
    start_vector       = opts[:start_vector]
    epsilon            = opts[:epsilon]            || 0.01
    max_iterations     = opts[:max_iterations]     || 1000

    # Added this so that we could get a custom list of tuneable intervals & prime_weights in there
    hd_config          = opts[:hd_config]          || HD::HDConfig.new
    goal_vector        = opts[:goal_vector]

    tuneable_data      = opts[:tuneable_data]     || get_tuneable_data(NArray.to_na(start_vector), hd_config)
    banned_points      = opts[:banned_points]     || {}

    path = []
    # Load the list of tuneable intervals, reject the rejects
    tuneable = hd_config.tuneable
    tuneable.sort_by! {|x| x.distance(HD.r, hd_config)}
    tuneable.reject! {|x| (x.distance(HD.r, hd_config) ** -1) == 0}

    lowest = NArray.int(*start_vector.shape)
    lowest.fill! 1
    current_point = start_vector
    current_cost = NMath.sqrt(((get_angle(current_point, start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
    best_point_so_far = current_point
    best_cost_so_far = current_cost
    
    path << start_vector
    
    initial_run = true
    interval_index = 0
   
    max_iterations.times do |iter|
      begin
        # puts "Iteration #{iter}"
        # puts "Now #{current_cost} away at #{current_point.to_a}"
        print "\rIteration #{iter}: #{current_cost} away at #{current_point.to_a}"
        cost = NMath.sqrt(((tuneable_data[true,1,true,true] - goal_vector) ** 2).sum(0))

        # If this is the first run-through, keep the interval index the same
        if initial_run 
          interval_index = 0
        end
      
        begin          
          ind_x, ind_y = sort_by_cost(cost, interval_index)
          best_interval = tuneable_data[true,0,ind_x,ind_y]
          # path << change_inner_interval(current_point, ind_y, HD.r(*best_interval))
          possible_interval = change_inner_interval(current_point, ind_y, HD.r(*best_interval))
          
          while banned_points.has_key? HD.narray_to_string possible_interval
            interval_index += 1
            if interval_index >= cost.size
              banned_points[HD.narray_to_string possible_interval] = 1
              bad = path.pop
              banned_points[HD.narray_to_string bad] = 1
              current_point = path[-1]
              initial_run = true
              current_cost = NMath.sqrt(((get_angle(path[-1], start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
              break
            end
            ind_x, ind_y = sort_by_cost(cost, interval_index)
            best_interval = tuneable_data[true,0,ind_x,ind_y]
            possible_interval = change_inner_interval(current_point,ind_y,HD.r(*best_interval))
          end
          
          if banned_points.has_key? HD.narray_to_string possible_interval
            next
          end
          path << possible_interval

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
      
        # print "Trying interval #{HD.r(*best_interval)} at #{ind_y}"
      
        if NMath.sqrt(((get_angle(path[-1], start_vector, hd_config)[0..1] - goal_vector) ** 2).sum) < current_cost
          current_cost = NMath.sqrt(((get_angle(path[-1], start_vector, hd_config)[0..1] - goal_vector) ** 2).sum)
        else
          banned_points[HD.narray_to_string path[-1]] = path[-1]
          path.pop
          initial_run = false
          # puts "banning #{banned_points[-1].to_a}"
          next
        end
   
        if current_cost < epsilon
          current_point = path[-1]
          break
        else
          # Update the data table
          tuneable_data[true,1,true,true] += get_angle(current_point, start_vector, hd_config)[0..1]
          current_point = path[-1]
          if current_cost < best_cost_so_far
            best_point_so_far = current_point
            best_cost_so_far = current_cost
          end
          initial_run = true
        end
        # puts "Now #{current_cost} away at #{current_point.to_a}"
      rescue RangeError => er
        puts "\nRangeError -- skipping this one"
        puts er.message
        print er.backtrace.join("\n")
        banned_points[HD.narray_to_string path[-1]] = path[-1]
        path.pop
        initial_run = false
        next
      end
    end
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
      
      def self.dist_#{sym}(*args)
        @@#{sym}.call(*args)
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
  # start_vector = HD::Ratio.from_s "1/1 2/1 3/2 2/3 16/9 32/27 8/3 2/1 3/1"
  start_vector = NArray[[1, 1], [1, 1], [8, 1], [28, 3], [98, 9], [196, 15], [1568, 75], [392, 25], [1176, 25]]
  # start_vector = NArray[[1, 1], [1, 1], [8, 1], [64, 7], [512, 49], [4096, 147], [32768, 735], [8192, 245], [12288, 245]]
  # distance: 0.3492063492028571

  opts = {}
  opts[:epsilon] = 0.44444444 / 28.0
  opts[:hd_config] = hd_config
  opts[:start_vector] = start_vector
  opts[:max_iterations] = 100000
  angle = (-73.952222 / 180.0) * NMath::PI
  interval = 0.44444444444 / 14.0

  # This gives you the inverse
  # angle += NMath::PI

  # distance = 0.346895
  # y = NMath.sin(angle) * distance
  # x = NMath.cos(angle) * distance
  # opts[:goal_vector] = NArray[x, y]
  # results << [MM.get_olm_search.call(opts)]
  # results[-1] << MM.get_angle(results[-1][0], start_vector, hd_config)
  # print results[-1].to_a
  # hc = 0.09653419811914568
  # ec = -0.3355983058912564
  hc = -0.01021989303518335 
  ec = -0.021476582975154146 
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