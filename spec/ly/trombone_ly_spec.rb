require_relative "../../hd.rb"
require_relative "../../lib/ly/ly.rb"
require_relative "../../lib/ly/trombone_ly.rb"

describe HD::TromboneLily do
  # When I pass the TromboneLily object a file of JSON data, I want it to 
  # generate a score where each voice is on its own location. This will require
  # a few steps: 
  # 
  # 1. iterating once through the path and breaking each voice into its own array
  # 2. iterating through each of these arrays and turning them into lilypond
  #    - perhaps this step should be done in batches, and in between batches it
  #    should have a line break or something, for readability
  # 
  # get_voice works. Now we need to transfer each voice into a lilypond line.
  before(:each) do
    @tl = HD::TromboneLily.new
  end
  
  it "initializes" do
    @tl.should be_instance_of(HD::TromboneLily)
  end
  
  context "with json data" do
    before(:each) do
      @tl.json = '{"vectors":[{"voices":[{"slide":[9,16],"partial":[1,1],"ratio":[9,16]},{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]},{"voices":[{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]}]}'
    end
    
    it "contains json data" do
      @tl.json.should eq('{"vectors":[{"voices":[{"slide":[9,16],"partial":[1,1],"ratio":[9,16]},{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]},{"voices":[{"slide":[9,16],"partial":[2,1],"ratio":[9,8]},{"slide":[9,16],"partial":[3,1],"ratio":[27,16]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]},{"slide":[9,16],"partial":[4,1],"ratio":[9,4]}]}]}')
    end
    
    it "gets a voice" do
      @tl.get_voice(0).should eq(['{"slide":[9,16],"partial":[1,1],"ratio":[9,16]}','{"slide":[9,16],"partial":[2,1],"ratio":[9,8]}'])
    end
    
    it "gets a lilypond voice" do
      @tl.offset = HD::Ratio[1, 9]
      @tl.get_lily_voice(0).should eq("c,,,1*16/9 c,,1*8/9")
    end
    
    context "with rests activated" do
      before(:each) do
        @tl.leading_rests = true
      end
      
      it "should create durations with leading rests" do
        note = HD.r(3, 2)
        @tl.offset = HD.r
        @tl.get_duration(note).should eq(["1*1/3", "1*2/3"])
      end
      
      it "should make leading rests add" do
        note = HD.r(99, 16)
        @tl.offset = HD.r
        @tl.get_duration(note).should eq(["1*83/99", "1*16/99"])
      end
      
      it "should create lilypond voices with leading rests" do
        @tl.get_lily_voice(2).should eq("r1*11/27 g,,1*16/27 r1*5/9 c,1*4/9")
      end
    end
  end
end




