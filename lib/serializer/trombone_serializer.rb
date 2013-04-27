# This will be a mixin for the NArray elements when they will be turned into JSON

require 'json'
require_relative '../hd_core.rb'

module TromboneSerializer
  # Will be included into valid NArrays
  def to_json *a
    case self.dim
    when 2
      slide = HD::Ratio.from_na self[true, 0]
      partial = HD::Ratio.from_na self[true, 1]
      {
        "slide" => slide.to_a,
        "partial" => partial.to_a,
        "ratio" => (slide * partial).to_a
      }.to_json(*a)
    when 3
      voices = []
      self.shape[-1].times do |element|
        voices << self[true, true, element]
      end
      {
        "voices" => voices
      }.to_json(*a)
    when 4
      vectors = []
      self.shape[-1].times do |element|
        vectors << self[true, true, true, element]
      end
      {
        "vectors" => vectors
      }.to_json(*a)
    end
  end
  
  # Opening the metaclass of JSON in order to redefine class methods
  class << JSON
    alias_method :old_parse, :parse
    # Overrides the parse method in order to try and recognize when it sees the
    # trombone parameters. This pays attention to the keys "slide", "partial", and
    # "voices" to see what level of search path it is.
    def parse(source, opts={})
      j = self.old_parse(source, opts)
      if j["slide"] && j["partial"]
        return NArray[NArray.to_na(j["slide"]), NArray.to_na(j["partial"])]
      elsif j["voices"]
        voices = []
        j["voices"].each do |voice|
          voices << parse(voice.to_json, opts)
        end
        return NArray.to_na(voices)
      elsif j["vectors"]
        vectors = []
        j["vectors"].each do |vector|
          vectors << parse(vector.to_json, opts)
        end
        return NArray.to_na(vectors)
      end
      j
    end
  end
end