require_relative "../../hd.rb"
require_relative "../../lib/ly/ly.rb"

describe HD::Lily do
  before(:each) do
    @ly = HD::Lily.new
  end
  
  it "instantiates" do
    @ly.should be_instance_of(HD::Lily)
  end
  
  it "has octave markers" do
    @ly.oct.should have(11).things
  end
  
  it "gets a notename" do
    note = HD::Ratio[3, 2]
    note_name = @ly.get_notename note
    note_name.should eq("g'")
  end
  
  it "gets a duration" do
    note = HD::Ratio[3, 2]
    @ly.get_duration(note).should eq("1*2/3")
    @ly.get_duration(HD.r(4,3)).should eq("1*3/4")
  end
  
  it "gets a lilypond note" do
    note = HD::Ratio[3, 2]
    @ly.get_lily_note(note).should eq("g'1*2/3")
  end
  
  it "gets a lilypond string" do
    notes = [HD::Ratio[3, 2], HD::Ratio[4, 3]]
    @ly.get_lily_string(notes).should eq("g'1*2/3 f'1*3/4")
  end
  
  it "gets a lilypond array" do
    notes = [HD::Ratio[3, 2], HD::Ratio[4, 3]]
    @ly.get_lily_array(notes).should eq(["g'1*2/3", "f'1*3/4"])
  end
  
  it "can change offset" do
    notes = [HD::Ratio[3, 2], HD::Ratio[4, 3]]
    @ly.offset = HD.r(9,8)
    @ly.get_lily_string(notes).should eq("a'1*2/3 g'1*3/4")
  end
  
  it "changes octave with offset" do
    note = HD.r(3,2)
    @ly.offset = HD.r(1,2)
    @ly.get_notename(note).should eq("g")
  end
  
  # Now we test a variety of cases for different ratios
  it "gets a notename with fifth harmonic" do
    note = HD::Ratio[5, 4]
    @ly.get_notename(note).should eq("eDf'")
  end
  
  it "gets a notename with seventh harmonic" do
    note = HD::Ratio[7, 4]
    @ly.get_notename(note).should eq("bflatDs'")
    @ly.get_notename(HD.r(7,6)).should eq("eflatDs'")
    @ly.get_notename(HD.r(49,32)).should eq("aflatDsDs'")
    @ly.get_notename(HD.r(32,49)).should eq("eUsUs")
  end
end