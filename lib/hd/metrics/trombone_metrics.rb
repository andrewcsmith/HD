# Provides the metrics for the piece all description all delay

require_relative '../../hd-mm.rb'

class TromboneMetrics
  attr_reader :metrics, :range
  
  def initialize opts = {}
    @metrics = opts[:metrics] || {}
    @range = opts[:range] || nil
    # Only initialize these default metrics if they are not already defined.
    @metrics[:pressure] ||= {:proc => default_pressure_metric, :key => :ratio}
    @metrics[:position] ||= {:proc => default_position_metric, :key => :partial}
  end
  
  def default_pressure_metric
    ->(v) do
      results_vector = NArray.float(v.shape[1])
      a = v
      config = MM::DistConfig.new :scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => MM::DELTA_FUNCTIONS[:abs_diff]
      results_vector.size.times do |i|
        aa = a.to_a
        aa.delete_at i
        b = NArray.to_na(aa)
        results_vector[i] = MM.dist_ucm(a, b, config)
      end
      results_vector
    end
  end
  
  def default_position_metric
    ->(v) do
      results_vector = NArray.float(v.shape[1])
      # Range for the trombone piece
      partial_range = NArray[[[1, 1], [8, 1]], [[2, 1], [10, 1]], [[3, 1], [12, 1]], [[4, 1], [16, 1]]]
      results_vector.size.times do |i|
        a = HD::Ratio.from_na v[true, i]
        b = HD::Ratio.from_na partial_range[true, 1, i]
        results_vector[i] = (a.to_f - 1.0) / (b.to_f - 1.0)
      end
      results_vector
    end
  end
  
  def parse_chord chord, opts = {:metric => :all}
    case opts[:metric]
    when :all
      # Cycle through each metric and call #parse_chord
      results = @metrics.map do |k, v|
        { k => (parse_chord chord, :metric => k) }
      end
      # Go through the results
      results.each do |m|
        m.each do |k, v|
          v.to_a.each_with_index do |value, index|
            chord[index][k.to_s] = value
          end
        end
      end
    else
      m = opts[:metric]
      c = chord.map {|x| x[@metrics[m][:key].to_s]}
      return @metrics[m][:proc].call NArray.to_na(c)
    end
    chord
  end
  
  def scale_metrics chords, opts = {:max_value => 1.0}
    # Set default maximum values
    max = {}
    max["pressure"] = 0
    max["position"] = 0
    # Parse the chord and add the unscaled metric results
    chords.map! do |chord|
      {"voices" => parse_chord(chord["voices"])}
    end
    chords.each do |chord|
      chord["voices"].each do |voice|
        max.each_key do |m|
          max[m] = voice[m] > max[m] ? voice[m] : max[m]
        end
      end
    end
    chords.each do |chord|
      chord["voices"].each do |voice|
        max.each do |m, v|
          # puts "#{m}, #{v}"
          voice[m] *= (opts[:max_value] / v)
        end
      end
    end
    {"vectors" => chords}
  end
end