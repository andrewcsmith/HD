The HD library contains structures and search functions based around James Tenney's notion of Harmonic Distance. It provides ways of measuring both the harmonic distance of a single interval and what Tenney called the "HD-sum", or the sum of the harmonic distances of all 2-combination intervals in a given aggregate.

The other theoretical sources, specific to the performance of music in just intonation, is the range of "tuneable intervals" developed by Marc Sabat and Wolfgang Von Schweinitz. This is a list of intervals that can be tuned by ear with relative accuracy, without the aid of an electronic tuner.

## Using HD::Ratio
  # You can create new Ratio objects
	HD::Ratio[3,2] # => HD::Ratio.int(2): [ 3, 2 ]
	HD::Ratio.from_s("3/2") == HD::Ratio[3, 2] # => true
	HD.r(3,2) == HD::Ratio[3, 2] # => true
	
	# You can get the distance from the Ratio to 1/1
	HD.r(3,2).distance # => 2.58496
	HD.r(9,8).distance # => 6.169925
	# You can also get the distance from the Ratio to another Ratio
	HD.r(3,2).distance HD.r(4,3) # => 6.169925
	# You can also pass a HDConfig object to, for example, ignore octave displacement
	HD.r(3,2).distance(HD.r(4,3), HD::HDConfig.new(:pc_only => true)) # => 3.169925
	# ...or to double the effect of octave displacement
	HD.r(3,2).distance(HD.r(4,3), HD::HDConfig.new(:prime_weights => [4, 3])) # => 9.169925
	
	# You can also get useful info for annotating scores or making SuperCollider mockups
	# Like the overall cents and the deviation of the interval from the nearest 12TET pitch (rounded)
	HD.get_cents_from_vector([HD.r(4,3), HD.r(3,2)]) # => NArray.float(2,2): [ [ 498.045, -2.0 ], [ 701.955, 2.0 ] ] 
	# Despite the method name, you don't actually need a full vector
	HD.get_cents_from_vector HD.r(4,3) # => NArray.float(2): [ 498.045, -2.0 ]
	# You can also get frequencies
	HD.get_frequencies_from_vector(HD::Ratio.from_s "3/2 4/3") # => NArray.float(2): [ 660.0, 586.667 ] 
	# These can be from any base frequency
	HD.get_frequencies_from_vector(HD::Ratio.from_s("3/2 4/3"), 330) # => NArray.float(2): [ 495.0, 440.0 ] 
	
	# Finally, HD::Ratio objects are Comparable and Enumerable
	HD.r(3,2) > HD.r(4,3) # => true
	HD.r(3,2) < HD.r(4,3) # => false
	HD.r(3,2) <=> HD.r(4,3) # => 1
	HD.r(3,2).each {|x| print "#{x}"} # => nil (prints "32")
	HD.r(3,2).map {|x| x * 2.0} # => HD::Ratio.int(2): [ 6, 4 ]
	
	# And they also respond to basic arithmetic
	HD.r(3,2) - HD.r(4,3) # => HD::Ratio.int(2): [ 1, 6 ] 
	HD.r(3,2) * HD.r(4,3) # => HD::Ratio.int(2): [ 2, 1 ]

Finally, there are some fun extra connections to the [Morphological Metrics](http://www.github.com/avianism/Morphological-Metrics) library elsewhere on Github. However, it is not 100% confirmed that all of these HD objects will work with the standard branch, so I maintain [my own fork of Morphological Metrics](http://www.github.com/andrewcsmith/Morphological-Metrics) that is adapted to work with the HD library. One of these days we will merge the two.