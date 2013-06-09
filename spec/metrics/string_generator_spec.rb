require 'hd/metrics/string_generator.rb'
require 'hd/metrics/trombone_metrics.rb'
require_relative './helpers.rb'

RSpec.configure do |c|
  c.include Helpers
  
  def generate_string_input
    # Generate a string of 12 chords
    chords = generate_chords 12
    tm = TromboneMetrics.new
    tm.scale_metrics chords
  end
end

describe StringGenerator do
  describe "parse" do
    context "when given valid input" do
      # Valid input is a Ruby hash / json object
      # 
      # {
      #   "vectors": [
      #     {
      #       "voices": [
      #         {
      #           "ratio": []
      #           "slide": []
      #           "partial": []
      #           "pressure": float
      #           "position": float
      #         }
      #       ]
      #     }
      #   ]
      # }
      # 
      let(:input) { generate_string_input }
      let(:results) { StringGenerator.new.parse input }
      
      describe "valid input" do
        let(:subject) { input }
        it "includes vectors" do
          input.should include("vectors")
        end
        it "has 12 vectors" do
          input["vectors"].should have(12).items
        end
        it "includes voices" do
          input["vectors"][0].should include("voices")
        end
        it "has 4 voices" do
          input["vectors"][0]["voices"].should have(4).items
        end
      end
      
      describe "valid output" do
        # Examine the collection of voices
        let(:subject) { results }
        it { should be_instance_of Array }
        it { should have(input["vectors"][0]["voices"].size).items }
        
        it "has onset in first measure" do
          results[0][0]["measure"]["onset"].should be_true
        end
        
        describe "each voice" do
          # Examine the collection of measures
          let(:subject) { results[0] }
          it { should be_instance_of Array }
          it { should have(input["vectors"].size).items }
        end
        
        describe "each measure" do
          # Examine one voice, one measure
          let(:subject) { results[0][0]["measure"] }
          it { should include("ratio") }
          it { should include("onset") }
          it { should include("line width") }
          it { should include("line height") }
          it { should_not include("slide") }
          it { should_not include("partial") }
        end
      end
    end
  end # end of #parse
end