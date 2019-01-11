require_relative '../5/png'
require_relative '../6/lib/jpeg'
require_relative '../6/lib/jpeg_encoder'
require 'progress_bar'

path_to_file = ARGV[0]
parts = path_to_file.split('.')
file_name = parts[0..-2].join('.')
file_extension = parts[-1]

if %w[jpg jpeg].include?(file_extension)
  jpeg = Jpeg.new(path_to_file)
  png = Png.new(nil)
  png.header = {
    :width       => jpeg.width,
    :height      => jpeg.height,
    :bit_depth   => 8,
    :palette     => 0,
    :color       => 1,
    :alpha       => 0,
    :compression => 0,
    :filtering   => 0,
    :interlacing => 0
  }
  pixels = jpeg.export_pixels
  png.import_pixels(pixels)
  byte_stream = png.pack_image
  packed_stream = byte_stream.pack('C*')
  File.write("#{file_name}.#{file_extension}.png", packed_stream)
elsif file_extension == 'png'
  png = Png.new(path_to_file)
  pixels = png.export_pixels
  width = png.header[:width]
  height = png.header[:height]
  write("#{file_name}.#{file_extension}.jpg", pixels, width, height)
end