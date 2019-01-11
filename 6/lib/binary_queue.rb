class BinaryQueue
  attr_accessor :queue, :queue_length

  def initialize(stream)
    @stream = stream
    @queue = 0
    @queue_length = 0
    @index = -1
  end

  def next(length = 1)
    if length > @queue_length
      while @queue_length < length
        byte = @stream[@index += 1]
        @queue |= byte << (24 - @queue_length)
        @queue %= 2**32
        @queue_length += 8
      end
    end
    output = ((@queue >> (32 - length)) & ((1 << length) - 1))
    @queue_length -= length
    @queue <<= length
    @queue %= 2**32
    output
  end

  def empty?
    @stream[@index + 1].nil?
  end
end