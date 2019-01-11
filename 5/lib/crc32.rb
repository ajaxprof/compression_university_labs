class Crc32
  def initialize
    @crc_table = []
    @crc_table_computed = false
    make_crc_table
  end  

  def update(buf)
    update_crc(0xFFFFFFFF, buf, buf.length)
  end

  private

  def make_crc_table
    256.times do |n|
      c = n
      8.times do |k|
        if c & 1 == 1
          c = 0xEDB88320 ^ (c >> 1)
        else
          c >>= 1
        end  
      end
      @crc_table[n] = c
    end
    @crc_table_computed = true
  end

  def update_crc(crc, buf, len)
    data = buf.is_a?(String) ? buf.chars.map(&:ord) : buf
    c = crc
    make_crc_table unless @crc_table_computed
    len.times do |n|
      c = @crc_table[(c ^ data[n]) & 0xFF] ^ (c >> 8)
    end
    c
  end
end