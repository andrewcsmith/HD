# Notes about compatibility between Harmonic Distance and Morphological Metrics

## For the HD::Ratio class (Euclidian Distance):

### direction metrics:

No problems (use default config settings)

### magnitude metrics:

#### All Metrics:
    scale = :absolute

#### Unordered Magnitudes:

We first sum the differences so that we are only working with a single number

	inter_delta = ->(a,b) { (Math.log2((a/b).to_f)).abs }
		
#### Ordered Magnitudes:

We find the inter-vector delta for each corresponding pair, thus we pass the inter_delta function two arrays of pairs

	inter_delta = ->(a, b) { 
		new = NArray.object(a.total)
		for i in 0...a.total
			new[i] = (Math.log2((a[i]/b[i]).to_f).abs)
		end
		new	
	}

#### Combinatorial Magnitudes:

We collect all the possible combinations and compare it pair by pair (rather than two vectors at once)

    intra_delta = ->(a,b) { (Math.log2((a/b).to_f)).abs }

#### Linear Magnitudes:

For Linear Magnitudes, we pass two vectors to the delta function to find the deltas between each internal pair in series.

	intra_delta = ->(a, b) { 
		new = NArray.object(a.total)
		for i in 0...a.total
			new[i] = (Math.log2((a[i]/b[i]).to_f).abs)
		end
		new	
	}

## Harmonic Distance:

see deltas.rb

### direction metrics

Perhaps, one could measure increasing or decreasing harmonic distance. We'll figure this out later though.

### OCM

Necessary to use an intra_delta that is basically just :distance with the addition of a config option, to specify and control prime_weights and other parameters.
intra_delta = get_harmonic_distance_delta_single
inter_delta = MM::DELTA_FUNCTIONS[:abs_diff] 

### OLM

intra_delta = get_harmonic_distance_delta (See deltas.rb)
inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]

SEARCH FUNCTIONS!
================

Currently, search functions don't work. The culprit seems to be mm.rb:1064-65. This method of using a discrete step size and adding it to each element of the current vector does not seem to work.

In the sense of harmonic distance, it may be difficult to change the step size like this. Adding or subtracting will greatly increase the harmonic distance, so this needs to be changed to * or /.

POSSIBLE SOLUTION:
==================

Index the list of tuneable intervals by harmonic distance. Need to find a linear way to traverse possible intervals to move by.

MM.find_point_at_distance({
:v1 => m, 
:d => 0.5, 
:dist_func => MM.olm, 
:search_opts => {:epsilon => 1.0, :start_step_size => HD::Ratio.new(16,15), :return_full_path => true},
:config => c, 
:allow_duplicates => true})

MM.metric_path({
:v1 => m,
:v2 => l,
:metric => MM.ocm,
:config => c,
:cheat => true
})