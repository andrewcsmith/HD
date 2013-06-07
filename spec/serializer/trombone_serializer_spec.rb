require_relative '../../lib/serializer/trombone_serializer.rb'

describe TromboneSerializer do
  
  it "returns json from a single pitch" do
    test_pitch = NArray[[9, 16], [1, 1]]
    test_pitch.extend TromboneSerializer
    test_pitch.to_json.should eq('{"slide":[9,16],"partial":[1,1],"ratio":[9,16]}')
  end
  
end