require_relative '../../lib/hd.rb'

module Helpers
  def get_slide_position
    [[9, 16], [27, 32], [27, 40], [81, 128], [45, 64]].sample
  end
  
  def generate_chord voices = 4
    chord = []
    voices.times do
      chord << {"partial" => [(4..12).to_a.sample, 1], "slide" => get_slide_position}
      chord[-1]["ratio"] = (HD::Ratio[*chord[-1]["partial"]] * HD::Ratio[*chord[-1]["slide"]]).to_a
    end
    chord
  end
  
  def generate_chords n
    chords = []
    n.times do
      chords << {"voices" => generate_chord}
    end
    chords
  end
end