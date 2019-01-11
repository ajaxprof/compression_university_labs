require 'zlib'
require_relative 'png_parse_exception'

class Png
  attr_accessor :header, :chunks

  def initialize(path_to_file)
    begin
      @raw_data = File.read(path_to_file).bytes
      raise PngParseException.new('>>>>> not a PNG signature <<<<<') unless is_png?(@raw_data)
      load_chunks
      load_header
      load_data_stream
    rescue Exception
      @chunks = [{ :length=>0, :type=>"IEND", :data=>[], :crc32=>2923585666 }]
    end  
  end

  def pack_image
    update_data_chunks
    update_header_chunk
    [ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A ] + pack_chunks
  end  

  def export_pixels
    pixels = @data_stream.unpack('C*').each_slice(1 + @header[:width] * 3).to_a
    bpp = 3
    modes = pixels.map(&:shift)
    pixels.size.times do |i|
      mode = modes[i]
      pixels[i].size.times do |j|
        break if mode == 0x00
        if mode == 0x01
          pixels[i][j] = (pixels[i][j] + default(pixels, i, j - bpp)) % 256
        end
        if mode == 0x02
          pixels[i][j] = (pixels[i][j] + default(pixels, i - 1, j)) % 256
        end
        if mode == 0x03
          pixels[i][j] = (pixels[i][j] + (default(pixels, i, j - bpp) + default(pixels, i - 1, j)) / 2) % 256
        end  
        if mode == 0x04
          pixels[i][j] = (pixels[i][j] + paeth(default(pixels, i, j - bpp), default(pixels, i - 1, j), default(pixels, i - 1, j - bpp))) % 256
        end
      end
    end
    pixels.flatten.each_slice(3).to_a
  end

  def import_pixels(pixels)
    padded_pixels = pixels.flatten.each_slice(@header[:width] * 3).to_a
    padded_pixels.each{ |slice| slice.unshift(0) }
    @data_stream = padded_pixels.flatten.pack('C*')
  end

protected

  def is_png?(raw_data)
    raw_data[0..7] == [ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A ]
  end

  def default(pixels, i, j, default = 0)
    return default if j < 0 || i < 0
    pixels[i][j]
  end  

  def load_chunks
    @chunks = []
    offset = 8
    loop do
      break if @raw_data[offset..-1].length < 12
      length  = @raw_data[offset + 0]  << 0x18
      length += @raw_data[offset + 1] << 0x10
      length += @raw_data[offset + 2] << 0x08
      length += @raw_data[offset + 3]
      type    = @raw_data[offset + 4..offset + 7].map(&:chr).join
      data    = @raw_data[offset + 8..offset + length + 7]
      crc32   = @raw_data[offset + length + 8]  << 0x18
      crc32  += @raw_data[offset + length + 9] << 0x10
      crc32  += @raw_data[offset + length + 10] << 0x08
      crc32  += @raw_data[offset + length + 11]
      calculated_crc = Zlib::crc32(@raw_data[offset + 4..offset + length + 7].pack('C*'))
      @chunks << { :length => length, :type => type, :data => data, :crc32 => crc32 } if crc32 == calculated_crc
      raise PngParseException.new(">>>>> corrupted chunk at #{offset} <<<<<") unless crc32 == calculated_crc
      offset += length + 12
    end
  end

  def pack_chunks
    data = []
    chunks = @chunks.select{ |x| x[:type] == 'IHDR' } + @chunks.select{ |x| x[:type] == 'PLTE' } + @chunks.select{ |x| x[:type] == 'IDAT' } + @chunks.select{ |x| x[:type] == 'IEND' }
    chunks.each do |chunk|
      data << ((chunk[:length]  & 0xFF000000) >> 0x18)
      data << ((chunk[:length]  & 0x00FF0000) >> 0x10)
      data << ((chunk[:length]  & 0x0000FF00) >> 0x08)
      data << ((chunk[:length]  & 0x000000FF) >> 0x00)
      data += chunk[:type].bytes
      data += chunk[:data]
      data << ((chunk[:crc32]   & 0xFF000000) >> 0x18)
      data << ((chunk[:crc32]   & 0x00FF0000) >> 0x10)
      data << ((chunk[:crc32]   & 0x0000FF00) >> 0x08)
      data << ((chunk[:crc32]   & 0x000000FF) >> 0x00)
    end
    data
  end  

  def load_header
    chunk         = @chunks.select{ |x| x[:type] == 'IHDR' }[0]
    data          = chunk[:data]
    width         = data[0] << 0x18
    width        += data[1] << 0x10
    width        += data[2] << 0x08
    width        += data[3]
    height        = data[4] << 0x18
    height       += data[5] << 0x10
    height       += data[6] << 0x08
    height       += data[7]
    bit_depth     = data[8]
    palette       = data[9] & 1
    color         = data[9] & 2
    alpha         = data[9] & 4
    compression   = data[10]
    filtering     = data[11]
    interlacing   = data[12]
    @header = {
      :width       => width,
      :height      => height,
      :bit_depth   => bit_depth,
      :palette     => palette,
      :color       => color >> 1,
      :alpha       => alpha >> 2,
      :compression => compression,
      :filtering   => filtering,
      :interlacing => interlacing
    }
  end

  def update_header_chunk
    data = []
    data << ((@header[:width]  & 0xFF000000) >> 0x18)
    data << ((@header[:width]  & 0x00FF0000) >> 0x10)
    data << ((@header[:width]  & 0x0000FF00) >> 0x08)
    data << ((@header[:width]  & 0x000000FF) >> 0x00)
    data << ((@header[:height] & 0xFF000000) >> 0x18)
    data << ((@header[:height] & 0x00FF0000) >> 0x10)
    data << ((@header[:height] & 0x0000FF00) >> 0x08)
    data << ((@header[:height] & 0x000000FF) >> 0x00)
    data << (@header[:bit_depth])
    data << (@header[:palette] | (@header[:color] << 1) | (@header[:alpha] << 2))
    data << (@header[:compression])
    data << (@header[:filtering])
    data << (@header[:interlacing])
    @chunks.reject!{ |chunk| chunk[:type] == 'IHDR' }
    @chunks << { :length => 13, :type => 'IHDR', :data => data, :crc32 => Zlib::crc32('IHDR' + data.pack('C*')) }
  end

  def update_data_chunks
    streamdata = Zlib::Deflate.deflate(@data_stream, Zlib::DEFAULT_COMPRESSION)
    data = streamdata.unpack('C*')
    @chunks.reject!{ |chunk| chunk[:type] == 'IDAT' }
    @chunks << { :length => data.length, :type => 'IDAT', :data => data, :crc32 => Zlib::crc32('IDAT' + data.pack('C*')) }
  end

  def load_data_stream
    zstream = Zlib::Inflate.new
    @chunks.select{ |x| x[:type] == 'IDAT' }.each{ |chunk| zstream << chunk[:data].pack('C*') }
    @data_stream = zstream.finish
    zstream.close
  end

  def paeth(a, b, c)
    pc = c
    pa = b - pc
    pb = a - pc
    pc = (pa + pb).abs
    pa = pa.abs
    pb = pb.abs
    return a if pa <= pb && pa <= pc
    return b if pb <= pc
    return c
  end
end