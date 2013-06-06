require './hd.rb'

# Gets a Lilypond-friendly notename from a given ratio.
# Could also perhaps be used to generate supercollider mockups using my HE library for SC.

module HD
  class Ratio
    @@basenames = ["d", "a", "e", "b", "fsharp", "csharp", "gsharp", "dsharp", "asharp", "esharp", "bsharp", "fflat", "cflat", "gflat", "dflat", "aflat", "eflat", "bflat", "f", "c", "g"]
    @@fivealts = ["", "Df", "DfDf", "DfDfDf", "UfUfUf", "UfUf", "Uf"]
    @@sevenalts = ["", "Ds", "DsDs", "DsDsDs", "UsUsUs", "UsUs", "Us"]
    @@elevenalts = ["", "Ue", "UeUe", "UeUeUe", "DeDeDe", "DeDe", "De"]
    @@oct = ["'", "''", "'''", "''''", "'''''", ",,,,,", ",,,,", ",,,", ",,", ",", ""]
    def get_notename
      factors = self.factors
      # create the steps up to the 11th harmonic (for now)
      steps = factors[1] + factors[2] * 4 + factors[3] * -2 + factors[4] * -1
      n = @@basenames[steps].dup
      n << @@fivealts[factors[2]] << @@sevenalts[factors[3]] << @@elevenalts[factors[4]]
      # TODO: This is a hardcoded offset for the violin piece. It should be explicitly set. offset should be the inverse of whatever tuning offset from c we're using
      offset = HD.r(9,8)
      oct_num = (Math.log2((self * offset).to_f)).floor
      n << @@oct[oct_num]
      n
    end
    
    def get_duration
      "1*#{self[1]}/#{self[0]}"
    end
    
    def get_lily_note
      notename = self.get_notename
      duration = self.get_duration
      notename + duration
    end
  end
  
  def self.get_lily_string n
    n = n.to_a
    string = ""
    n.each {|x| string << HD.r(*x).get_lily_note << " " }
    string
  end
  
  def self.get_lily_array n
    (get_lily_string n).split(" ")
  end
end



if __FILE__ == $0
  x = HD.r(15,16)
  n = NArray[[1, 1], [1, 1], [11, 3], [77, 24], [539, 384], [539, 48], [539, 60], [539, 80], [1617, 160]]
  puts x.get_notename
  puts x.get_duration
  puts x.get_lily_note
  puts HD.get_lily_string n
end

__END__

f = File.open("results/02 E-SE ALL.txt", "r")
text = f.read
text.lines {|x| olds << x.match(/Lowest OLD: (.*)/)}
olds.delete_if {|x| (x == nil)}
olds.map! {|x| x[1]}
olds.map! {|x| eval("NArray#{x}")}

deltas = olds.map {|x| MM.vector_delta(x, 1, MM.get_inner_interval_delta, MM::INTERVAL_FUNCTIONS[:pairs])}

lily = olds.map{|x| HD.get_lily_string(x)}

d'1*1/1 d''1*1/2 a'1*2/3 g1*3/2 a'1*2/3 d'1*1/1 e''1*4/9 b'1*16/27 fsharp''1*32/81 
d'1*1/1 d''1*1/2 a'1*2/3 bDf1*6/5 eDf''1*9/20 aDf'1*27/40 bDf''1*3/10 fsharpDf''1*2/5 csharpDf'''1*4/15 
d'1*1/1 d''1*1/2 a'1*2/3 g1*3/2 c''1*9/16 f'1*27/32 bDfUs'1*189/320 fsharpDfUs'1*63/80 csharpDfUs''1*21/40 
d'1*1/1 d''1*1/2 a'1*2/3 fDs'1*6/7 bflatDs''1*9/28 eflatDs''1*27/56 fDs'''1*3/14 cDs''1*2/7 gDs'''1*4/21 
d'1*1/1 d''1*1/2 a'1*2/3 g1*3/2 bUs1*7/6 fsharpUs'1*7/9 gsharpUs''1*28/81 dsharpUs''1*112/243 asharpUs''1*224/729 
d'1*1/1 d''1*1/2 a'1*2/3 g1*3/2 aUs1*21/16 eUs'1*7/8 fsharpUs''1*7/18 csharpUs''1*14/27 gsharpUs''1*28/81 
d'1*1/1 d''1*1/2 a'1*2/3 bDe1*11/9 dDsDe'1*22/21 aDsDe'1*44/63 bDsDe''1*176/567 fsharpDsDe''1*704/1701 csharpDsDe'''1*1408/5103 
d'1*1/1 d''1*1/2 a'1*2/3 fDs'1*6/7 bDf'1*3/5 eDf'1*9/10 fsharpDf''1*2/5 csharpDf''1*8/15 gsharpDf''1*16/45 
d'1*1/1 d''1*1/2 a'1*2/3 gDs'1*16/21 csharpDf''1*8/15 fsharpDf'1*4/5 gsharpDf''1*16/45 dsharpDf''1*64/135 asharpDf''1*128/405 
d'1*1/1 d''1*1/2 bflatUf'1*5/8 aflatUfDs'1*5/7 cUf''1*5/9 fUf'1*5/6 gUf''1*10/27 dUf''1*40/81 aUf''1*80/243 
d'1*1/1 d''1*1/2 a'1*2/3 gDs'1*16/21 a'1*2/3 e'1*8/9 fsharp''1*32/81 csharp''1*128/243 gsharp''1*256/729 
d'1*1/1 d''1*1/2 a'1*2/3 fDs'1*6/7 a'1*2/3 d'1*1/1 gsharpDfUs'1*7/10 dsharpDfUs'1*14/15 asharpDfUs'1*28/45 
d'1*1/1 d''1*1/2 bflatUf'1*5/8 aflatUfDs'1*5/7 eflatUfUe''1*5/11 aflatUfUe'1*15/22 cflatUfDsUe'1*45/77 gflatUfDsUe'1*60/77 dflatUfDsUe''1*40/77 
d'1*1/1 d''1*1/2 bflatUf'1*5/8 aflatUfDs'1*5/7 cUf''1*5/9 fUf'1*5/6 aUfUs'1*35/54 eUfUs'1*70/81 bUfUs'1*140/243

# The following regular expression allows to find the last note value in the string, so that it can be tied over by a normal whole note (which should have a fermata)

old_lines[0] = "d'1*1/1 d''1*1/2 a'1*2/3 g1*3/2 a'1*2/3 d'1*1/1 e''1*4/9 b'1*16/27 fsharp''1*32/81"
old_lines[0] =~ /([\w,']+)\d[\S]*\s*$/
# For the first violin
old_lines[0].gsub(/([\w,']+)(\d[\S]*\/[\d]+\s*)[\w,']+(\d[\S]*\/[\d]+\s*)/, '\1\2~ \1\3')
# For the second violin
old_lines[0].sub(/([\w,']+)/,"r").gsub(/([\w,']+)(\d[\S]*\/[\d]+\s*)[\w,']+(\d[\S]*\/[\d]+\s*)/, '\1\2~ \1\3')

first_vln = lily.map {|x| x.gsub(/([\w,']+)(\d[\S]*\/[\d]+\s*)[\w,']+(\d[\S]*\/[\d]+\s*)/, '\1\2~ \1\3')}
second_vln = lily.map {|x| x.sub(/([\w,']+)/,"r").gsub(/([\w,']+)(\d[\S]*\/[\d]+\s*)[\w,']+(\d[\S]*\/[\d]+\s*)/, '\1\2~ \1\3')}

olds.map {|x|
  sum = Rational(0,1)
  x.to_a.each {|y|
    sum += Rational(y[1], y[0])
  }
  sum
}