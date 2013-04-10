require '../hd-mm.rb'
require 'test/unit'

# TODO: Work all of these difference distances out by hand, to make sure that it's all correct. Right now, I'm just asserting that these things I've done today will stay the same.

class MMTest < Test::Unit::TestCase
  
  def test_strings
    input_string = "1/1 4/3 16/7 96/49 216/49 864/245"
    ratios = HD::Ratio.from_s(input_string)
    assert_equal(NArray[HD.r, HD.r(4,3), HD.r(16,7), HD.r(96,49), HD.r(216,49), HD.r(864, 245)], ratios)
  end
  
  def test_distance
    # These harmonic distances are taken from the Marc Sabat / Robin Hayward
    # paper Tuneable Brass Intervals
    assert_in_delta(3.5849625, HD.r(4,3).distance, 0.001)
    assert_in_delta(4.32192809, HD.r(5,4).distance, 0.001)
    assert_in_delta(5.80735, HD.r(8,7).distance, 0.001)
    assert_in_delta(5.39232, HD.r(7,6).distance, 0.001)
  end

  def test_olm
    v1 = NArray[HD.r(1,1), HD.r(3,2), HD.r(7,4), HD.r(11,9), HD.r(6,5)]
    v2 = NArray[HD.r(4,3), HD.r(6,5), HD.r(9,8), HD.r(5,3), HD.r(9,5)]

    # Harmonic Distance Configurations
    d_config = HD::HDConfig.new

    c_olm = MM::DistConfig.new
    c_olm.scale = :absolute
    c_olm.intra_delta = MM.get_harmonic_distance_delta(d_config)
    # At this point, we are in the logarithmic domain so we can resort to
    # subtraction to find the difference
    c_olm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]
    c_olm.int_func = MM::INTERVAL_FUNCTIONS[:pairs]
    
    assert_in_delta(0.215, MM.dist_olm(v1, v2, c_olm), 0.001)
  end
  
  def test_simple_olm
    v1 = HD::Ratio.from_s "1/1 2/1 5/4"
    v2 = HD::Ratio.from_s "1/1 7/4 21/16"
    
    d_config = HD::HDConfig.new
    
    c_olm = MM::DistConfig.new
    c_olm.scale = :none
    c_olm.intra_delta = MM.get_harmonic_distance_delta(d_config)
    c_olm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]
    c_olm.int_func = MM::INTERVAL_FUNCTIONS[:pairs]
    
    assert_in_delta(2.772, MM.dist_olm(v1, v2, c_olm), 0.001)
  end
  
  def test_ocm
    v1 = NArray[HD.r(1,1), HD.r(3,2), HD.r(7,4), HD.r(11,9), HD.r(6,5)]
    v2 = NArray[HD.r(4,3), HD.r(6,5), HD.r(9,8), HD.r(5,3), HD.r(9,5)]

    # Harmonic Distance Configurations

    d_config = HD::HDConfig.new

    c_ocm = MM::DistConfig.new
    c_ocm.scale = :absolute
    # One the usage of a specified proc lets the user specify a config object
    # to use (prime_weights, etc)
    c_ocm.intra_delta = MM.get_harmonic_distance_delta(d_config)
    # At this point, we are in the logarithmic domain so we can resort to
    # subtraction to find the difference
    c_ocm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]
    # This doesn't hurt anything.
    c_ocm.int_func = MM::INTERVAL_FUNCTIONS[:pairs]
    
    assert_in_delta(0.242, MM.dist_ocm(v1, v2, c_ocm), 0.001)
  end
  
  def test_ulm
    v1 = NArray[HD.r(1,1), HD.r(3,2), HD.r(7,4), HD.r(11,9), HD.r(6,5)]
    v2 = NArray[HD.r(4,3), HD.r(6,5), HD.r(9,8), HD.r(5,3), HD.r(9,5)]

    # Harmonic Distance Configurations

    d1_config = HD::HDConfig.new
    d1 = MM.get_harmonic_distance_delta(d1_config)

    c_ulm = MM::DistConfig.new
    c_ulm.scale = :absolute
    # One the usage of a specified proc lets the user specify a config object
    # to use (prime_weights, etc)
    c_ulm.intra_delta = MM.get_harmonic_distance_delta(d1_config)
    # At this point, we are in the logarithmic domain so we can resort to
    # subtraction to find the difference
    c_ulm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]
    c_ulm.int_func = MM::INTERVAL_FUNCTIONS[:pairs]
    
    assert_in_delta(0.063, MM.dist_ulm(v1, v2, c_ulm), 0.001)
    # Assert commutative equality
    assert(MM.dist_ulm(v2, v1, c_ulm) == MM.dist_ulm(v1, v2, c_ulm))
  end
  
  def test_ucm
    v1 = NArray[HD.r(1,1), HD.r(3,2), HD.r(7,4), HD.r(11,9), HD.r(6,5)]
    v2 = NArray[HD.r(4,3), HD.r(6,5), HD.r(9,8), HD.r(5,3), HD.r(9,5)]

    # Harmonic Distance Configurations

    d1_config = HD::HDConfig.new
    d1 = MM.get_harmonic_distance_delta(d1_config)

    c_ucm = MM::DistConfig.new
    c_ucm.scale = :absolute
    # One the usage of a specified proc lets the user specify a config object
    # to use (prime_weights, etc)
    c_ucm.intra_delta = MM.get_harmonic_distance_delta(d1_config)
    # At this point, we are in the logarithmic domain so we can resort to
    # subtraction to find the difference
    c_ucm.inter_delta = MM::DELTA_FUNCTIONS[:abs_diff]
    
    assert_in_delta(0.028, MM.dist_ucm(v1, v2, c_ucm), 0.001)
    # Assert commutative equality
    assert(MM.dist_ucm(v2, v1, c_ucm) == MM.dist_ucm(v1, v2, c_ucm))
  end
  
end