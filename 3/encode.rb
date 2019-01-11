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

CODE_LENGTH = 15
INFORMATION_LENGTH ||= 7
CORRECTIBLE_ERRORS ||= 2

puts "=================================================="
puts "using (#{CODE_LENGTH}, #{INFORMATION_LENGTH}, #{CORRECTIBLE_ERRORS * 2 + 1}) BCH code"

path = ARGV[-1]
data = File.read path
slices = data.chars.map(&:ord).map{ |x| x.to_s(2).rjust(8, '0') }.join.chars.each_slice(INFORMATION_LENGTH).to_a.map{ |x| x.map!(&:to_i) }
last_block_size = slices[-1].size
appendix_length = INFORMATION_LENGTH - last_block_size
appendix = [0] * appendix_length
slices[-1] += appendix
encoded = slices.map{ |x| encode(x, CODE_LENGTH, INFORMATION_LENGTH, logging) }
encoded.map!{ |x| x.join.to_i(2) }
packed_encoded = encoded.pack('S*')
output_path = "#{path}.bch"
puts "writing code to #{output_path}"
File.write output_path, packed_encoded