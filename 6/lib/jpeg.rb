require_relative 'jpeg_reader'
require_relative 'jpeg_huffman_data'
require_relative 'jpeg_decoder'
require_relative 'utils'

class Jpeg
  attr_accessor :precision,
                :height,
                :width,
                :jpeg_reader,
                :ac_data,
                :dc_data,
                :components,
                :channels,
                :dqt_tables,
                :blocks


  def initialize(path_to_file)
    @path_to_file = path_to_file
    @jpeg_reader = JpegReader.new(path_to_file)
    load_baseline
    load_huffman_tables
    decode_sos
    load_dqt
    dequantize_channels
    revert_dct
    load_blocks
  end

  def export_pixels
    pixels = []
    @blocks.each do |block|
      block.each do |part|
        pixels += part[0].flatten.zip(part[1].flatten, part[2].flatten)
      end
    end
    pixels
  end

  def load_blocks
    @blocks = []
    i = 0
    @channels[0].each_slice(4) do |lum_matrices|
      y0 = lum_matrices[0].each_slice(8).to_a
      y1 = lum_matrices[1].each_slice(8).to_a
      y2 = lum_matrices[2].each_slice(8).to_a
      y3 = lum_matrices[3].each_slice(8).to_a
      cb = @channels[1][i].each_slice(8).to_a
      cr = @channels[2][i].each_slice(8).to_a
      i += 1
      block = [rgb_matrices(y0, cb, cr), rgb_matrices(y1, cb, cr), rgb_matrices(y2, cb, cr), rgb_matrices(y3, cb, cr)]
      @blocks << block
    end
  end

  def decode_sos
    sos_seg = @jpeg_reader.segments.find { |seg| seg.type == :SOS }
    decoder = JpegDecoder.new(sos_seg, @dc_data, @ac_data)
    @channels = decoder.channels
  end

  def revert_dct
    @channels.map! do |channel|
      channel.map do |matrix|
        reverse_discrete_cosine_transform(matrix).flatten
      end
    end
  end

  def load_dqt
    @dqt_tables = @jpeg_reader.segments
                              .select { |seg| seg.type == :DQT }
                              .map(&:payload)
                              .map { |table| table[3..-1] }
                              .map { |table| unzigzagify(table) }
  end

  def dequantize_channels
    @channels[0].map! { |matrix| matrix.map.with_index { |x, i| x * @dqt_tables[0][i] } }
    @channels[1].map! { |matrix| matrix.map.with_index { |x, i| x * @dqt_tables[1][i] } }
    @channels[2].map! { |matrix| matrix.map.with_index { |x, i| x * @dqt_tables[1][i] } }
  end

  def load_baseline
    baseline_segment_payload = @jpeg_reader.segments
                                           .find { |seg| seg.type == :SOF0 }
                                           .payload
    @precision = baseline_segment_payload[2]
    @height = (baseline_segment_payload[3] << 8) + baseline_segment_payload[4]
    @width = (baseline_segment_payload[5] << 8) + baseline_segment_payload[6]
    components_count = baseline_segment_payload[7]
    load_components(baseline_segment_payload[8..-1], components_count)
  end

  def load_components(payload, count)
    @components = Array.new(count) do |i|
      {
        id: payload[3 * i],
        horizontal: payload[3 * i + 1] >> 4,
        vertical: payload[3 * i + 1] & 0x0F,
        quantization_table_id: payload[3 * i + 2]
      }
    end
  end

  def load_huffman_tables
    @ac_data = JpegHuffmanData.new
    @dc_data = JpegHuffmanData.new
    dht_segments = @jpeg_reader.segments
                               .select { |seg| seg.type == :DHT }
    dht_segments.select { |seg| (seg.payload[2] & 0xF0).zero? }
                .each { |seg| @dc_data.load_seg(seg) }
    dht_segments.reject { |seg| (seg.payload[2] & 0xF0).zero? }
                .each { |seg| @ac_data.load_seg(seg) }
  end
end