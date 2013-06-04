require_relative "./ly.rb"
require_relative "../serializer/trombone_serializer.rb"

module HD
  class TromboneLily < Lily
    attr_accessor :json, :leading_rests
    
    def initialize opts={}
      super opts
      @json = nil
      # Default offset for the trombone piece
      @offset = HD.r(1,9)
      @leading_rests = false
    end
    
    def get_voice voice=nil
      path = JSON.parse(@json)
      path.extend TromboneSerializer
      path.get_voice voice
    end
    
    def get_lily_voice voice=nil
      json_voice = get_voice voice
      ratios = json_voice.map do |v|
        HD::Ratio.to_na JSON.old_parse(v)["ratio"]
      end
      get_lily_string ratios
    end
    
    def get_duration note
      if @leading_rests
        n = super note
        ["1*#{-1*(note[1] - note[0])}/#{note[0]}", n]
      else
        super note
      end
    end
    
    def get_lily_note note
      if @leading_rests
        [get_notename(nil) + get_duration(note)[0], get_notename(note) + get_duration(note)[1]].join(" ")
      else
        super note
      end
    end
  end
end