require 'progress_bar'
require_relative 'lzw'
require_relative 'color_reducer'
require_relative 'gif_parse_exception'

class Gif
  attr_accessor :header, :global_color_map, :image_descriptors, :lzw_min_code_length, :pixels, :chunks

  def initialize(raw_data)
    begin
      @raw_data = raw_data.dup
      raw_data = File.read(@raw_data).bytes
      raise GifParseException.new unless is_gif87a?(raw_data[0..5])
      load_header(raw_data[6..11])
      offset = 12 + @header[:color_table_size]
      load_color_map(raw_data[13..offset])
      load_image_descriptors(raw_data[(offset + 1)..-1])
      offset += 11
      load_code_parameters(raw_data[offset..offset])
      load_chunks(raw_data[(offset + 1)..-1])
      load_image_pixels
    rescue Exception
    end
  end

  def pack_image
    data = [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]
    reduce_colors if @pixels.uniq.size > 256 || @global_color_map.size > 256
    data << pack_header
    data << pack_color_map
    data << pack_chunks
    data.flatten
  end

  

  def reduce_colors
    @global_color_map = reduce_palette(@global_color_map) if @global_color_map.size > 256
    addendix_size = (2 ** (Math.log(@global_color_map.size) / Math.log(2)).ceil) - @global_color_map.size
    @global_color_map = @global_color_map + [[ 0, 0, 0 ]] * addendix_size
    @pixels = reduce_pixels(@pixels, @global_color_map)
  end  

  def is_gif87a?(raw_slice)
    raw_slice == [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]
  end

  def load_header(raw_slice)
    width      = raw_slice[0] + (raw_slice[1] << 8)
    height     = raw_slice[2] + (raw_slice[3] << 8)
    m          = (raw_slice[4] & 0x80) >> 7
    cr         = ((raw_slice[4] & 0x70) >> 4) + 1
    pixel      = (raw_slice[4] & 0x07) + 1
    background = raw_slice[5]
    @header = { width: width, height: height, global_color_map: m == 1, color_resolution: 2 ** cr, color_table_size: 3 * 2 ** pixel, background: background }
  end

  def pack_header
    width      = @header[:width]
    height     = @header[:height]
    m          = @header[:global_color_map] ? 1 : 0
    cr         = (Math.log(@header[:color_resolution]) / Math.log(2)).round - 1
    pixel      = (Math.log(@header[:color_table_size]) / Math.log(2)).round - 1
    background = @header[:background]
    flags = (m << 7) | (cr << 4) | (pixel)
    data = [ width & 255, width >> 8, height & 255, height >> 8, flags, background, 0 ]
  end  

  def load_color_map(raw_slice)
    @global_color_map = raw_slice.each_slice(3).to_a
  end

  def pack_color_map
    @global_color_map.flatten
  end  

  def load_image_descriptors(raw_data)
    offsets = raw_data.each_index.select{ |i| raw_data[i] == 0x2C }.map{ |x| x + 1 }[0..0]
    @image_descriptors = []
    offsets.each do |_i|
      left       = raw_data[_i + 0] + (raw_data[_i + 1] << 8)
      right      = raw_data[_i + 2] + (raw_data[_i + 3] << 8)
      width      = raw_data[_i + 4] + (raw_data[_i + 5] << 8)
      height     = raw_data[_i + 6] + (raw_data[_i + 7] << 8)
      m          = (raw_data[_i + 8] & 0x80) >> 7
      i          = (raw_data[_i + 8] & 0x40) >> 6
      pixel      = (raw_data[_i + 8] & 0x07) + 1
      @image_descriptors << { left: left, right: right, width: width, height: height, local_color_map: m == 1, interlaced_order: i == 1, color_table_size: 2 ** pixel }
    end
  end

  def load_code_parameters(raw_slice)
    @lzw_min_code_length = raw_slice[0] + 1
  end

  def load_chunks(raw_slice)
    @chunks = []
    loop do
      current_chunk_length = raw_slice[0]
      @chunks << raw_slice[1..current_chunk_length]
      raw_slice = raw_slice[(current_chunk_length + 1)..-1]
      break if raw_slice[0] == 0x3B
    end
    @chunks.pop
  end

  def pack_chunks
    @lzw_min_code_length = (Math.log(@global_color_map.size + 1) / Math.log(2)).ceil
    chunk_image_pixels
    data = [ 0x2C, 0 & 255, 0 >> 8, 0 & 255, 0 >> 8, @header[:width] & 255, @header[:width] >> 8, @header[:height] & 255, @header[:height] >> 8, 0 ]
    data << @lzw_min_code_length - 1
    @chunks[0].each_slice(255).to_a.each do |c|
      data << c.length
      data << c
    end
    data << [ 0x00, 0x3B ]
  end

  def load_image_pixels
    @pixels = decode(@raw_data).each_slice(3).to_a
  end

  def chunk_image_pixels
    @chunks = [ encode(@pixels, @global_color_map, @lzw_min_code_length) ]
  end  
end
