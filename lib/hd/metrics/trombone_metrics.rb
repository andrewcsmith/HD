# Provides the metrics for the piece all description all delay

require_relative '../../hd-mm.rb'

class TromboneMetrics
  attr_reader :metrics, :range
  
  def initialize opts = {}
    @metrics = opts[:metrics] || {}
    @range = opts[:range] || nil
    # Only initialize these default metrics if they are not already defined.
    @metrics[:pressure] ||= default_pressure_metric
    @metrics[:position] ||= default_position_metric
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
  
end