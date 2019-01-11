require_relative './node_queue'
require 'json'

class Huffman
  attr_accessor :root, :lookup, :input, :output

  def initialize(input)
    @input = input
    @root = NodeQueue.new(input).root
    @output = encode_string(input)
    @output = '0' * input.length if input.chars.sort[0] == input.chars.sort[-1]
    @lookup = {} if input.chars.sort[0] == input.chars.sort[-1]
    @lookup['0'] = input[0] if input.chars.sort[0] == input.chars.sort[-1]
  end

  def lookup
    return @lookup if @lookup
    @lookup = {}
    @root.walk do |node, code|
      @lookup[code] = node.symbol if node.leaf?
    end
    @lookup
  end

  def encode(char)
    @lookup_inverse = self.lookup.invert if @lookup_inverse.nil?
    @lookup_inverse[char]
  end

  def decode(code)
    self.lookup[code]
  end

  def encode_string(string)
    string.chars.map{|e| encode(e)}.join
  end

  def decode_string(code)
    string = ''
    subcode = ''
    len = code.chars.length
    last_step = 0.02
    code.chars.each_with_index do |bit, index|
      if index.to_f / len > last_step
        print '='
        last_step += 0.02
      end  
      subcode += bit
      decoded = decode(subcode)
      unless decoded.nil?
        string += decoded
        subcode = ''
      end
    end
    string
  end

  def dump
    Marshal::dump(@lookup)
  end  

  def self.load(data)
    dictionary = Marshal::load(data)
    agent = Huffman.new('')
    agent.lookup = dictionary
    agent
  end
end