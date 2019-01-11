require_relative './jpeg_segment'

class JpegReader
  attr_accessor :segments

  def initialize(path_to_file)
    stream = File.binread(path_to_file).unpack('C*')
    @segments = []
    offset = 0
    loop do
      @segments << segment = JpegSegment.new(stream[offset..-1])
      offset += segment.length
      break if segment.type == :EOI
    end
  end

end