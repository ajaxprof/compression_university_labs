def decode(data, min_code_length, palette_size)
  initial_dictionary  = palette_size.times.map{ |i| [ i ] } + %i[ CLEAR END ]
  dictionary          = initial_dictionary.dup
  binary_data         = data.map{ |x| x.to_s(2).rjust(8, '0').reverse }.join
  current_code_length = min_code_length
  buffer              = []
  previous            = nil
  current             = 0

  loop do
    current = binary_data[0..current_code_length - 1]
    binary_data.sub!(current, '')
    current = current.reverse.to_i(2)
    value = dictionary[current]
    if value == :CLEAR
      current_code_length = min_code_length
      dictionary = initial_dictionary.dup
      previous = nil
    elsif value == :END
      break
    elsif value.nil?
      buffer << [ previous, previous ]
      dictionary << [ previous, previous ]
    else  
      buffer << value
      dictionary << [ previous, value.flatten[0] ] if previous && !dictionary.map{|x| x.is_a?(Array) ? x.flatten : x }.include?([ previous, value.flatten[0] ].flatten)
      previous = value
      current_code_length += 1 if current_code_length < 12 && dictionary.size > 2 ** current_code_length - 1
    end
  end
  buffer.flatten
end

def encode(pixels, palette, lzw_min_code_length)
  clear_code = palette.size
  end_code = clear_code + 1
  dictionary = clear_code.times.map{ |i| [i] }
  dictionary << [ clear_code ]
  dictionary << [ end_code ]
  byte_stream = []
  code_buffer = []
  current_code_length = lzw_min_code_length
  byte_stream = [ clear_code, current_code_length ]

  puts "                         >>>>> encoding image pixels <<<<<"
  bar = ProgressBar.new(pixels.size)

  for i in 0..pixels.length - 1  
    code_buffer << index = palette.index(pixels[i])
    unless dictionary.include?(code_buffer)
      dictionary << code_buffer.dup
      code_buffer.pop
      byte_stream << dictionary.find_index(code_buffer)
      byte_stream << current_code_length
      current_code_length += 1 if (1 << current_code_length) + 1 == dictionary.size
      code_buffer = Array.new(1) { index }
    end
    if dictionary.size > 4095
      byte_stream += [ clear_code, current_code_length ]
      current_code_length = lzw_min_code_length
      dictionary = Array.new(clear_code){ |i| [i] }
      dictionary << [ clear_code ]
      dictionary << [ end_code ]
    end
    bar.increment!
  end

  byte_stream += [ dictionary.index(code_buffer), current_code_length ]
  byte_stream += [ end_code, current_code_length ]
  
  byte_stream.each_slice(2).map{ |pair| as_bits(pair[0], pair[1]) }.flatten!.each_slice(8).map{|x| x.join.reverse.to_i(2)}
end

private

def as_bits(value, length)
  (0..length - 1).map { |i| value[i] }
end
