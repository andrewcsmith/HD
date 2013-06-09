require 'hd/metrics/trombone_metrics.rb'
require_relative './helpers.rb'

RSpec.configure do |c|
  c.include Helpers
end

shared_examples "a single metric" do
  it { should_not be_nil }
  
  context "when passed a 4D NArray" do
    it "returns a 4D float NArray" do
      if input.is_a? Array
        results = subject.call *input
      else
        results = subject.call input
      end
      if input.is_a? Array
        input_size = input[0].size
      elsif input.is_a? NArray
        input_size = input.shape[-1]
      else
        raise ArgumentError
      end
      results.should be_instance_of NArray
      results.should have(input_size).float
      # puts results.inspect
    end
  end
end

describe TromboneMetrics do
  let(:tm) {TromboneMetrics.new}
  let(:ratios) { NArray[[27,10], [27,8], [63,16], [27,8]] }
  let(:partials) { NArray[[4, 1], [5, 1], [6, 1], [3, 1]] }
  
  it { should_not be_nil }
  
  describe "#metrics[:pressure]" do
    subject { tm.metrics[:pressure][:proc] }
    let(:input) { ratios }
    it_behaves_like "a single metric"
  end
  
  describe "#metrics[:position]" do
    subject { tm.metrics[:position][:proc] }
    let(:input) { partials }
    it_behaves_like "a single metric"
  end
  
  describe "#parse_chord" do
    subject { tm.send(:method, :parse_chord) }
    
    context "when passed an invalid chord" do
      it "raises an ArgumentError"
    end
    
    context "when passed a valid chord" do
      let(:chord) { generate_chord }
      
      it "has access to the chord" do
        chord.should_not be_nil
      end
      
      context "when only the pressure metric is specified" do
        let(:input) { [chord, :metric => :pressure, :key => :ratio] }
        it_behaves_like "a single metric"
      end
      
      context "when only the position metric is specified" do
        let(:input) { [chord, :metric => :position, :key => :pressure] }
        it_behaves_like "a single metric"
      end
      
      # This recursively calls each member of the metrics hash and adds them to the Array of voices
      context "when no metric is specified" do
        let(:results) { subject.call chord }
        it "returns an Array" do
          results.should be_instance_of Array
        end
        it "has 4 voices" do
          results.should have(4).items
        end
        it "has voices with pressure indication" do
          results[0]["pressure"].should be_instance_of Float
        end
        it "has voices with position indication" do
          results[0]["position"].should be_instance_of Float
        end
      end
    end
  end
  
  describe "#scale_metrics" do
    context "when passed a string of chords" do
      let(:number_of_chords) { (3..12).to_a.sample }
      let(:chords) { generate_chords number_of_chords }
      let(:results) { subject.scale_metrics chords }
      
      it "has chords" do
        # print chords
        chords.should_not be_nil
      end
      
      it "has results" do
        # print results
        results.should_not be_nil
      end
      
      it "returns collection of same size" do
        results["vectors"].should have(number_of_chords).items
      end
      
      it "returns collection of elements with results" do
        results.should satisfy do |r|
          r["vectors"].all? do |y|
            y["voices"].all? do |x| 
              (x.has_key? "pressure") && (x.has_key? "position")
            end
          end
        end
      end
      
      it "returns collection of elements with no value over 1.0" do
        results.should satisfy do |r|
          r["vectors"].all? do |y|
            y["voices"].all? do |x|
              (x["pressure"] <= 1.0) && (x["position"] <= 1.0)
            end
          end
        end
      end
      
      context "when passed a max_value over 1.0" do
        let(:max_value) {Random.rand(1.01..6.0)}
        let(:results) { subject.scale_metrics(chords, {:max_value => max_value}) }
        
        it "returns collection of elements under max value" do
          results.should satisfy do |r|
            r["vectors"].all? do |y|
              y["voices"].all? do |x|
                (x["pressure"] <= max_value) && (x["position"] <= max_value)
              end
            end
          end
        end
        
        it "returns collection of elements over 1.0" do
          results.should satisfy do |r|
            r["vectors"].any? do |chord|
              chord["voices"].any? do |voice|
                voice["pressure"] > 1.0
              end
            end
          end
        end
      end
    end
  end
end