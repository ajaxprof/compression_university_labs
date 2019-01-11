require 'set'

GALOIS_FIELD_CAPACITY = 2

def validate_code_length(n)
	(1..10).each do |m|
		return m if (GALOIS_FIELD_CAPACITY ** m - 1) % n == 0
	end
	nil
end

def cyclotomic_fields(m)
	modulo_element = GALOIS_FIELD_CAPACITY ** m - 1
	fields = (0..modulo_element - 1).map do |x|
		field = Set[ x ]
		last = x
		loop do
			current = last * GALOIS_FIELD_CAPACITY % modulo_element
			field_full = field.include?(current)
			field << current unless field_full
			break if field_full
			last = current
		end
		field
	end
	fields.uniq.map(&:to_a)
end

def generator_polynomial(degree)
	case degree
	when 4
		[ 1, 0, 0, 1, 1 ]	
	when 8
		[ 1, 0, 0, 0, 1, 0, 1, 1, 1 ]
	when 10
		[ 1, 1, 1, 0, 1, 1, 0, 0, 1, 0, 1 ]
	end	
end