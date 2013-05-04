require 'test/unit'
require 'json'
require 'narray'
require_relative '../../lib/serializer/trombone_serializer.rb'

# Load in this string information in order from the below
PITCH_JSON = DATA.gets.chomp
VECTOR_JSON = DATA.gets.chomp
PATH_JSON = DATA.gets.chomp
PATH_ASCII = DATA.gets(nil).chomp

class TromboneSerializerTest < Test::Unit::TestCase
  def setup
    @test_path = NArray[[[[9, 16], [1, 1]], [[9, 16], [2, 1]], [[9, 16], [3, 1]], [[9, 16], [4, 1]]], [[[9, 16], [2, 1]], [[9, 16], [3, 1]], [[9, 16], [4, 1]], [[9, 16], [4, 1]]]]
    @test_vector = @test_path[true, true, true, 0]
    @test_pitch = @test_vector[true, true, 0]
    @test_pitch_json = PITCH_JSON
    @test_vector_json = VECTOR_JSON
    @test_path_json = PATH_JSON
    
    @test_path_ascii = PATH_ASCII
  end
  
  def test_pitch_should_return_serialized_json
    @test_pitch.extend TromboneSerializer
    assert_equal(@test_pitch_json, @test_pitch.to_json)
  end
  
  def test_vector_should_return_serialized_json
    @test_vector.extend TromboneSerializer
    assert_equal(@test_vector_json, @test_vector.to_json)
  end

  def test_path_should_return_serialized_json
    @test_path.extend TromboneSerializer
    assert_equal(@test_path_json, @test_path.to_json)
  end
  
  def test_pitch_should_parse_serialized_json
    assert_equal(@test_pitch, JSON.parse(@test_pitch_json))
  end
  
  def test_vector_should_parse_serialized_json
    assert_equal(@test_vector, JSON.parse(@test_vector_json))
  end
  
  def test_path_should_parse_serialized_json
    assert_equal(@test_path, JSON.parse(@test_path_json))
  end
  
  def test_path_should_return_ascii_score
    @test_path.extend TromboneSerializer
	assert_equal(@test_path_ascii, @test_path.to_ascii_score)
  end
end

__END__
{"slide":[9,16],"partial":[1,1],"ratio":[9,16]}
{"voices":[{"slide":[9,16],"partial":[1,1],"ratio":[9,16]},{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]}
{"vectors":[{"voices":[{"slide":[9,16],"partial":[1,1],"ratio":[9,16]},{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]},{"voices":[{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]}]}
9/16	9/8
9/8	27/16
27/16	9/4
9/4	9/4
