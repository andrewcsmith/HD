require "./hd.rb"

module HD
  require 'nokogiri'
  
  # Translates from an NArray of HDRatios (or 2-dimensional NVectors) into an XML file using Nokogiri
  class XMLTranslator
    require 'narray'
    
    attr_accessor :xml
    
    def initialize
      @xml = Nokogiri::XML::Document.new
      @xml << Nokogiri::XML::Node.new("root", @xml)
    end
    
    # Translates the vector into a <vector> element containing <ratio> elements with attributes n and d (for numerator and denominator)
    # Should allow for storage and recovery of vectors, as well as _hopefully_ translation to LilyPond, SuperCollider, etc.
    # Note that "ratio" is distinct from "note" in that it doesn't contain any duration or articulation
    # Therefore, "ratio" could be contained in a "note" element, as one possible property (this is probably not the best way to go about things)
    def add_vector v
      # Currently only takes a 2-dimensional NArrays
      if v.shape[0] == 2
        vector = Nokogiri::XML::Node.new("vector", @xml)
        for i in 0...v.shape[1]
          m = Nokogiri::XML::Node.new("ratio", @xml)
          m['n'], m['d'] = [v[[0...v.shape[0]],i].to_a[0].to_s, v[[0...v.shape[0]],i].to_a[1].to_s]
          vector.add_child m
        end
        @xml.root.add_child vector
      else
        warn "Did not supply the proper element to add_vector"
      end
    end
    
    def to_s
      @xml.to_xml
    end
    
  end
  
end