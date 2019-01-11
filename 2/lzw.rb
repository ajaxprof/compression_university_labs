require 'progress_bar'

ENCODING_SIZE = 1106

def to_binary(array)
  array.pack("S*")
end

def from_binary(binary)
  binary.unpack("S*")
end

def compress(to_compress)
  bar = ProgressBar.new(to_compress.size)
  dictionary = Hash.new
  ENCODING_SIZE.times do |ascii_code|
    dictionary[[ascii_code].pack('U*')] = ascii_code
  end
  s = ''
  index = 0
  to_compress.each_char.reduce([]) do |output, c|
    bar.increment!
    index = index.next
    if dictionary.include?(s + c)
      s = s + c
      output << dictionary[s] if index == to_compress.size
    else
      output << dictionary[s]
      output << dictionary[c] if index == to_compress.size
      dictionary[s + c] = dictionary.size
      s = c
    end
    output
  end
end

def uncompress(to_uncompress)
  dictionary = (0..ENCODING_SIZE.pred).to_a.map{ |e| [e].pack('U*') }
  output = Array.new
  current = to_uncompress.shift
  output << dictionary[current]
  bar = ProgressBar.new(to_uncompress.size)
  to_uncompress.each do |index|
    bar.increment!
    previous = current
    current = index
    if current <= dictionary.length
      s = current < dictionary.length ? dictionary[current] : dictionary[previous]
      output << s
      output << s[0] if current == dictionary.length
      dictionary << dictionary[previous] + s[0]
    else
      s = dictionary[previous]
      output << s
      dictionary << s
    end
  end
  output
end

path_to_file = ARGV[0]
if path_to_file.match /(.*)\.lzw/ or File.exists?("#{path_to_file}.lzw")
  path_to_file = "#{path_to_file}.lzw" unless path_to_file.match /(.*)\.lzw/
  content = File.read path_to_file
  stream = from_binary content
  plain = uncompress(stream).join
  File.write('_' + path_to_file.gsub('.lzw', ''), plain)
else
  content = File.read path_to_file
  compressed = compress content
  packed = to_binary compressed
  File.write("#{path_to_file}.lzw", packed)
  old_size = content.length
  new_size = packed.length
  ratio = old_size.to_f / new_size
  puts "ratio: #{ratio}"
end  