require 'matrix'
require 'polynomial'
require_relative './generator_polynomial'

def generator_matrix(generator_polynomial, n, k)
	degree = generator_polynomial.length - 1
	appendix = [0] * (n - degree - 1)
	vectors = k.times.map{ generator_polynomial + appendix }
	Matrix[ *vectors.each_with_index.map{ |vector, index| vector.rotate(-index) }]
end

def parity_check_matrix(generator_polynomial, n)
	degree = generator_polynomial.length - 1
	g = Polynomial[*generator_polynomial]
	vectors = n.times.map{ |index| (Polynomial[*([0] * index + [1])] % g).map{ |x| (x.to_i + 2) % 2 }.coefs }.map{ |vector| vector + [0] * (degree - vector.length) }
	Matrix::columns(vectors)
end

def encode(data, n = 15, k = 7, logging = [])
	data_polynomial = Polynomial[*data]
	generator_polynomial = Polynomial[*generator_polynomial(n - k)]
	puts "cyclotomic fields: #{cyclotomic_fields(4).inspect}" if logging.size > 0
	puts "generator polynomial of GF(16) over GF(2): #{generator_polynomial.coefs.each_with_index.map{ |x, i| x == 1 ? (i == 0 ? 'x' : "x^#{i}") : '' }.reject{ |x| x.length == 0 }.join(' + ')}" if logging.size > 0
	codeword_polynomial = (data_polynomial * generator_polynomial).map{ |x| x % 2 }
	logging.pop
	codeword_polynomial.coefs + [0] * (n - codeword_polynomial.coefs.length)
end	

def decode(data, n = 15, k = 7, logging = [])
	generator_polynomial_coefs = generator_polynomial(n - k)
	data_polynomial = Polynomial[*data]
	generator_polynomial = Polynomial[*generator_polynomial_coefs]
	puts "cyclotomic fields: #{cyclotomic_fields(4).inspect}" if logging.size > 0
	puts "generator polynomial of GF(16) over GF(2): #{generator_polynomial.coefs.each_with_index.map{ |x, i| x == 1 ? (i == 0 ? 'x' : "x^#{i}") : '' }.reject{ |x| x.length == 0 }.join(' + ')}" if logging.size > 0
	divident = data_polynomial / generator_polynomial
	divident = Polynomial[0] if divident.is_a?(Integer) && divident.zero?
	decoded_polynomial = divident.map{ |x| (x.to_i + 64) % 2 }
	parity_check_matrix = parity_check_matrix(generator_polynomial_coefs, n)
	syndrome_polynomial = (Matrix::rows([ data ]) * parity_check_matrix.transpose).row(0).to_a.map{ |x| x % 2 }
	decoded = decoded_polynomial.coefs + [0] * (k - decoded_polynomial.coefs.length)
	errors_count = syndrome_polynomial.reject(&:zero?).size
	puts "errors detected ... trying to fix ..." if errors_count > 0
	logging.pop
	decoded
end