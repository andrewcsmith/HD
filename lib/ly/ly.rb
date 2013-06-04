module HD
  class Lily
    attr_accessor :oct, :basenames, :fivealts, :sevenalts, :elevenalts, :offset
    
    def initialize opts={}
      @offset = opts[:offset]       || HD.r(1, 1)
      
      @oct = ["'", "''", "'''", "''''", "'''''", ",,,,,", ",,,,", ",,,", ",,", ",", ""]
      @basenames = ["c", "g", "d", "a", "e", "b", "fsharp", "csharp", "gsharp", "dsharp", "asharp", "esharp", "bsharp", "fdoublesharp", "cdoublesharp", "gdoublesharp", "ddoublesharp", "adoublesharp", "edoublesharp", "bdoublesharp", "fdoubleflat", "cdoubleflat", "gdoubleflat", "ddoubleflat", "adoubleflat", "edoubleflat", "bdoubleflat", "fflat", "cflat", "gflat", "dflat", "aflat", "eflat", "bflat", "f"]
      @fivealts = ["", "Df", "DfDf", "DfDfDf", "UfUfUf", "UfUf", "Uf"]
      @sevenalts = ["", "Ds", "DsDs", "DsDsDs", "UsUsUs", "UsUs", "Us"]
      @elevenalts = ["", "Ue", "UeUe", "UeUeUe", "DeDeDe", "DeDe", "De"]
    end
    
    def get_notename note
      # it's possible to pass a nil note to get a rest
      (note.is_a? NilClass) ? (return "r") : false
      note *= @offset
      factors = note.factors
      steps = factors[1] + factors[2] * 4 + factors[3] * -2 + factors[4] * -1
      n = @basenames[steps].dup
      n << @fivealts[factors[2]] << @sevenalts[factors[3]] << @elevenalts[factors[4]]
      # TODO: This causes an error on C notes that end up falling flat (they appear one octave too low)
      oct_num = (Math.log2((note).to_f)).floor
      n << @oct[oct_num]
      n
    end
    
    def get_duration note
      "1*#{note[1]}/#{note[0]}"
    end
    
    def get_lily_note note
      get_notename(note) + get_duration(note)
    end
    
    def get_lily_string notes
      notes.to_a.map do |n|
        get_lily_note HD::Ratio.from_na(n)
      end.join(' ')
    end
    
    def get_lily_array notes
      get_lily_string(notes).split(" ")
    end
  end
end