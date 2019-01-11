require_relative './lib/encoder'

logging = [nil]

error_param_index = ARGV.index('-t')
if error_param_index
	CORRECTIBLE_ERRORS = ARGV[error_param_index + 1].to_i
	if CORRECTIBLE_ERRORS == 1
		INFORMATION_LENGTH = 11
	elsif CORRECTIBLE_ERRORS == 2
		INFORMATION_LENGTH = 7
	elsif CORRECTIBLE_ERRORS == 3
		INFORMATION_LENGTH = 5
	end
end

CODE_LENGTH ||= 15
INFORMATION_LENGTH ||= 7

puts "=================================================="

path = ARGV[-1]
packed_data = File.read path
data = packed_data.unpack('S*')
data_binary = data.map{ |x| x.to_s(2).rjust(CODE_LENGTH, '0') }.map{ |x| x.split('').map(&:to_i) }
decoded_binary = data_binary.map{ |x| decode(x, CODE_LENGTH, INFORMATION_LENGTH, logging) }.flatten
slices = decoded_binary.each_slice(8).to_a
slices.pop if slices[-1].size < 8
decoded_data = slices.map{ |x| x.join.to_i(2) }.map(&:chr).join
output_path = "_#{path.gsub('.bch', '')}"
puts "writing code to #{output_path}"
File.write output_path, decoded_data