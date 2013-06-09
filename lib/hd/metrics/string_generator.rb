require_relative '../../hd-mm.rb'

class StringGenerator
  
  def initialize opts = {}
    @max_line_width = opts[:max_line_width_in_pixels] || 6.0
    @max_line_height = opts[:max_line_height] || 20.0
  end
  
  def parse input
    out = []
    input["vectors"].each_with_index do |vector, vector_index|
      vector["voices"].each_with_index do |voice, voice_index|
        # Temporary measure object
        m = {"measure" => voice}
        m["measure"].delete "partial"
        m["measure"].delete "slide"
        
        if input["vectors"][vector_index]["voices"][voice_index+1] && (voice["slide"] != input["vectors"][vector_index]["voices"][voice_index+1]["slide"])
          m["measure"]["onset"] = true
        else
          m["measure"]["onset"] = false
        end
        
        m["measure"]["line height"] = @max_line_height * (m["measure"]["position"] - 0.5) * 2.0
        m["measure"]["line width"] = @max_line_width * (m["measure"]["pressure"])
        
        out[voice_index] = (out[voice_index] ? (out[voice_index] + [m]) : [m])
      end
    end
    out
  end
end