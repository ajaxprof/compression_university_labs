require_relative './lib/huffman'

mode = 'COMPRESS'

if ARGV[0].downcase == '-c'
	mode = 'COMPRESS'
elsif ARGV[0].downcase == '-d'
	mode = 'DECOMPRESS'
end

output_file_name = ARGV[2]

data = File.read(ARGV[1])

if mode == 'COMPRESS'
	agent = Huffman.new(data)
	lookup = agent.dump
	binary_string = agent.output
	binary_string_length = binary_string.length
	data_string = binary_string.chars.each_slice(8).to_a.map{ |slice| slice.join.to_i(2).chr }.join
	content = "#{binary_string_length}DELIMETER#{lookup}DELIMETER#{data_string}"
	File.write(output_file_name, content)
else
	parts = data.force_encoding("iso-8859-1").split("DELIMETER")
	binary_string_length, lookup_string, data_string = parts
	binary_string = data_string.chars.map{ |e| e.ord.to_s(2).rjust(8, '0') }
	binary_string_padded_length = binary_string.join.length
	delta = binary_string_padded_length - binary_string_length.to_i
	binary_string[-1] = binary_string[-1][delta..-1]
	agent = Huffman.load(lookup_string)
	string = agent.decode_string(binary_string.join)
	File.write(output_file_name, string)
end	