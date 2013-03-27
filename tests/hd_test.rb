require '../hd.rb'
require 'test/unit'

class HDTest < Test::Unit::TestCase
	
	def setup
		@hd_config = HD::HDConfig.new
	end
	
	def test_tuneable_intervals_are_all_present
		assert_equal(@hd_config.tuneable, [HD::Ratio[1,1], HD::Ratio[8,7], HD::Ratio[7,6], HD::Ratio[6,5], HD::Ratio[5,4], HD::Ratio[9,7], HD::Ratio[13,10], HD::Ratio[4,3], HD::Ratio[7,5], HD::Ratio[10,7], HD::Ratio[3,2], HD::Ratio[11,7], HD::Ratio[8,5], HD::Ratio[13,8], HD::Ratio[5,3], HD::Ratio[12,7], HD::Ratio[7,4], HD::Ratio[9,5], HD::Ratio[11,6], HD::Ratio[13,7], HD::Ratio[2,1], HD::Ratio[13,6], HD::Ratio[11,5], HD::Ratio[9,4], HD::Ratio[7,3], HD::Ratio[19,8], HD::Ratio[12,5], HD::Ratio[5,2], HD::Ratio[18,7], HD::Ratio[13,5], HD::Ratio[8,3], HD::Ratio[11,4], HD::Ratio[14,5], HD::Ratio[17,6], HD::Ratio[20,7], HD::Ratio[23,8], HD::Ratio[3,1], HD::Ratio[16,5], HD::Ratio[13,4], HD::Ratio[10,3], HD::Ratio[17,5], HD::Ratio[7,2], HD::Ratio[18,5], HD::Ratio[11,3], HD::Ratio[15,4], HD::Ratio[19,5], HD::Ratio[4,1], HD::Ratio[17,4], HD::Ratio[13,3], HD::Ratio[9,2], HD::Ratio[23,5], HD::Ratio[14,3], HD::Ratio[19,4], HD::Ratio[24,5], HD::Ratio[5,1], HD::Ratio[21,4], HD::Ratio[16,3], HD::Ratio[11,2], HD::Ratio[28,5], HD::Ratio[17,3], HD::Ratio[23,4], HD::Ratio[6,1], HD::Ratio[25,4], HD::Ratio[19,3], HD::Ratio[13,2], HD::Ratio[20,3], HD::Ratio[7,1], HD::Ratio[22,3], HD::Ratio[15,2], HD::Ratio[23,3], HD::Ratio[8,1]])
	end
  
  def test_strings_should_parse_into_ratios
    input_string = "1/1 4/3 16/7 96/49 216/49 864/245"
    ratios = HD::Ratio.from_s(input_string)
    assert_equal(NArray[HD.r, HD.r(4,3), HD.r(16,7), HD.r(96,49), HD.r(216,49), HD.r(864, 245)], ratios)
  end
  
	# Tests that the distance of every tuneable interval matches with what we expect
	File.open("./tuneable_with_distances.txt") do |file|
		file.each do |line|
			if line =~ /(\d+)\/(\d+)\t([\d\.]+)/
				interval = NArray[$1.to_f, $2.to_f].to_i
				distance = $3.to_f
				# puts "Creating test for #{interval.to_a.to_s} at distance #{distance.to_s}"
			  self.send(:define_method, "test_distance_should_work_for_prime_#{interval[0].to_s}_#{interval[1].to_s}".to_sym) do
			    assert_in_delta(distance, HD.r(*interval).distance, 0.001)
				end
			else
				"Problem with line #{file.lineno}"
			end
		end
	end
	
	def test_ratios_should_be_comparable
		x = HD::Ratio[3,2]
		y = HD::Ratio[4,3]
		
		assert_equal(1, x <=> y)
		assert_equal(true, x > y)
		assert_equal(false, x < y)
		assert_equal(true, x != y)
	end
  
end