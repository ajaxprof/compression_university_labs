require_relative 'jpeg_segment'

class JpegHuffmanData
  attr_accessor :tables

  def initialize
    @tables = []
  end

  def load_seg(dht_seg)
    raise 'not a dht' unless dht_seg.is_a?(JpegSegment) && dht_seg.type == :DHT
    data = dht_seg.payload[2..-1]
    id = data[it = 0] & 0x0F
    counts = Array.new(16) { data[it += 1] }
    @tables[id] ||= {}
    code = 0
    16.times do |i|
      counts[i].times do
        @tables[id][[i + 1, code]] = data[it += 1]
        code += 1
      end
      code <<= 1
    end
  end
end