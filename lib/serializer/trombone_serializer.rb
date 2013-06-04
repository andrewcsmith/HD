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
  
  def to_ascii_score
    case self.dim
    when 2
    when 3
    when 4
      string = ""
      # Add the index numbers to each
      self.shape[3].times do |index|
        string << "#{index}\t"
      end
      string.chomp!("\t")
      string << "\n"
      
      # Iterate over each instrument (on its own line)
      self.shape[2].times do |voice|
        voice = self.shape[2] - voice - 1
        line = ""
        self.shape[3].times do |element|
          note = self[true, true, voice, element]
          note.extend TromboneSerializer
          # call the old parsing method, so we can access it with Hash
          ratio = JSON.old_parse(note.to_json)["ratio"]
          line << "#{ratio[0]}/#{ratio[1]}\t"
        end
        line << "\n"
        self.shape[3].times do |element|
          note = self[true, true, voice, element]
          note.extend TromboneSerializer
          # call the old parsing method, so we can access it with Hash
          slide = JSON.old_parse(note.to_json)["slide"]
          line << "#{slide[0]}/#{slide[1]}\t"
        end
        string << line.chomp("\t") << "\n\n"
      end
      return string.chomp
    end
    # return "9/16\t9/8\n9/8\t27/16\n27/16\t9/4\n9/4\t9/4"
  end
  
  # Only works for the path right now
  def get_voice voice=nil
    path = JSON.old_parse(self.to_json)
    voices = []
    path["vectors"][0]["voices"].size.times {voices << []}
    # puts "#{path.inspect}"
    path["vectors"].each do |vec|
      vec["voices"].each_with_index do |voi, i|
        voices[i] << voi.to_json
      end
    end
    voice ? voices[voice] : voices
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