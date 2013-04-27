require 'test/unit'
require 'json'
require 'narray'
require_relative '../../lib/serializer/trombone_serializer.rb'

# Load in this string information in order from the below
PITCH_JSON = DATA.gets.chomp
VECTOR_JSON = DATA.gets.chomp

class TromboneSerializerTest < Test::Unit::TestCase
  def setup
    @test_vector = NArray[[[9, 16], [1, 1]], [[9, 16], [2, 1]], [[9, 16], [3, 1]], [[9, 16], [4, 1]]]
    @test_pitch = @test_vector[true, true, 0]
    @test_pitch_json = PITCH_JSON
    @test_vector_json = VECTOR_JSON
  end
  
  def test_pitch_should_return_serialized_json
    @test_pitch.extend TromboneSerializer
    assert_equal(@test_pitch_json, @test_pitch.to_json)
  end
  
  def test_vector_should_return_serialized_json
    @test_vector.extend TromboneSerializer
    assert_equal(@test_vector_json, @test_vector.to_json)
  end
  
  def test_pitch_should_parse_serialized_json
    assert_equal(@test_pitch, JSON.parse(@test_pitch_json))
  end
  
  def test_vector_should_parse_serialized_json
    assert_equal(@test_vector, JSON.parse(@test_vector_json))
  end
end

__END__
{"slide":[9,16],"partial":[1,1],"ratio":[9,16]}
{"voices":[{"slide":[9,16],"partial":[1,1],"ratio":[9,16]},{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]}