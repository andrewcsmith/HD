require './hd.rb'
require '../Morphological-Metrics/mm.rb'

file = File.open("./topology_iv.txt", "r")
ratio_pattern = /\[ (\d+), (\d+) \]/
vector_start = /^\[ \[/

current_list_index = -1
vectors = Array.new

file.readlines.each do |line|
  if vector_start =~ line
    vectors << Array.new
    current_list_index += 1
  end
  if (ratio_pattern =~ line) != nil
    match = Regexp.last_match
    vectors[current_list_index] << HD::Ratio[match[1].to_i, match[2].to_i]
  end
end

vectors.map! {|x| NArray.to_na(x)}

puts (vectors[0].inspect)