module MM
  # Need to populate the list of tuneable intervals with how they change
  # things We should only need to do this once -- from then on, we're always
  # judging the vectors from how they change things relative to the initial
  # interval vector
  # 
  # Loads the tuneable_data vector like so:
  # [[x, y], [tuneable list], [fod index]] 
  # First is the movement it causes [x, y]
  # Second is the list of tuneable intervals
  # Third is the index of each first-order differential
  # 
  # Currently, this method only works for the OLM. Generalizing it to fit the
  # combinatorial metrics is a priority. How is it possible to figure out whether the metrics are linear or combinatorial? We will need to add a manual config at this point. it can be decoded later upon refactoring.
  def self.get_tuneable_data(origin, get_coords, hd_config)
    # Initialize an empty NArray with all data
    tuneable_data = NArray.float(2, hd_config.tuneable.size, origin.shape[1]-1)
    # TODO: Vectorize these loops!
    # Iterate through each first differential index
    # i = index of the first differential
    tuneable_data.shape[2].times do |i| 
      # Iterate through each tuneable interval
      # j = index of each tuneable interval
      tuneable_data.shape[1].times do |j|
        begin
          # find the first differential of the vector
          vector_delta = (MM.vector_delta(origin, 1, MM::DELTA_FUNCTIONS[:hd_ratio], MM::INTERVAL_FUNCTIONS[:pairs])).dup
          # switch out each of the intervals in the first differential with
          # one of the tuneable intervals
          vector_delta[true,i] = hd_config.tuneable[j]
          # log how the vector moved from the origin
          tuneable_data[true,j,i] = get_coords.(MM.vector_from_differential(vector_delta), origin)
        # rescue
        #   puts "index #{j}, #{i} didn't seem to work"
        end
      end
    end
    tuneable_data 
  end
end