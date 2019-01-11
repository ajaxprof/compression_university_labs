require_relative 'utils'
require_relative 'jpeg_segment'
require_relative 'tables'

def encode_jpeg(pixels_safe, width, height)
  pixels = pixels_safe.dup
  pixels.map! do |pixel|
    to_ycbcr(pixel)
  end
  lines = pixels.each_slice(width).to_a
  blocks = []
  lines.each_slice(8) do |slice|
    (width / 8).times do |i|
      blocks << slice.map { |line| line[(8 * i)..(8 * (i + 1) - 1)] }
    end
  end
  blocks.map! do |block|
    lum_matrix = block.map { |row| row.map { |pixel| pixel[0] } }
    cb_matrix  = block.map { |row| row.map { |pixel| pixel[1] } }
    cr_matrix  = block.map { |row| row.map { |pixel| pixel[2] } }
    [lum_matrix, cb_matrix, cr_matrix]
  end
  blocks.map! { |block| block.map { |dim| discrete_cosine_transform(dim) } }
  blocks.map! { |block| block.map { |dim| quantize(dim) } }
  blocks.map! { |block| block.map { |dim| zigzagify(dim) } }
  bar = ProgressBar.new(blocks.flatten.length)
  blocks.each do |block|
    block.each_with_index do |dim, i|
      htdc = i == 0 ? @YDC_HT : @UVDC_HT
      htac = i == 0 ? @YAC_HT : @UVAC_HT
      channel_index = i % 3
      process_du(dim, htdc, htac, channel_index)
      bar.increment!
    end
  end
end

def write(file_name, pixels, width, height)
  @data = []
  @data += JpegSegment.raw_data(:SOI)
  @data += JpegSegment.raw_data(:APP0, [74, 70, 73, 70, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0])
  @data += JpegSegment.raw_data(:DQT, [0, 3, 2, 2, 2, 2, 2, 3, 2, 2, 2, 3, 3, 3, 3, 4, 6, 4, 4, 4, 4, 4, 8, 6, 6, 5, 6, 9, 8, 10, 10, 9, 8, 9, 9, 10, 12, 15, 12, 10, 11, 14, 11, 9, 9, 13, 17, 13, 14, 15, 16, 16, 17, 16, 10, 12, 18, 19, 18, 16, 19, 15, 16, 16, 16])
  @data += JpegSegment.raw_data(:SOF0, [8, height / 0x100, height & 0xFF, width / 0x100, width & 0xFF, 3, 1, 0b00010001, 0, 2, 0b00010001, 0, 3, 0b00010001, 0])
  @data += JpegSegment.raw_data(:DHT, dht_bytes)
  @data += JpegSegment.raw_data(:SOS, [3, 1, 0, 2, 17, 3, 17, 0, 63, 0])
  encode_jpeg(pixels, width, height)
  @data += JpegSegment.raw_data(:EOI)
  File.write(file_name, @data.pack('C*'))
end

def process_du(du, htdc, htac, channel_index)
  eob = htac[0]
  m16 = htac[16]
  @dc ||= []
  diff = du[0] - @dc[channel_index] || du[0]
  @dc[channel_index] = du[0]
  if diff == 0
    write_bits(htdc[0])
  else
    pos = 32767 + diff
    write_bits(htdc[@category[pos]])
    write_bits(@bitcode[pos])
  end
  end0pos = 63
  while (end0pos > 0) && (du[end0pos] == 0)
    end0pos -= 1
  end
  if end0pos == 0
    write_bits(eob)
  end
  i = 1
  while i <= end0pos
    startpos = i
    while du[i] == 0 && i <= end0pos
      i += 1
    end
    nrzeroes = i - startpos
    if nrzeroes >= 16
      lng = nrzeroes >> 4
      1.upto(lng) do
        write_bits(m16)
      end
      nrzeroes = nrzeroes & 0xF
    end
    pos = 32767 + du[i]
    write_bits(htac[(nrzeroes << 4) + @category[pos]])
    write_bits(@bitcode[pos])
    i += 1
  end
  if end0pos != 63
    write_bits(eob)
  end
end

def write_bits(bs)
  val = bs[0]
  @bytepos ||= 0
  @bytenew ||= 0
  posval = bs[1] - 1
  while (posval >= 0)
    if val & (1 << posval)
      @bytenew |= (1 << @bytepos)
    end
    posval -= 1
    @bytepos -= 1
    if @bytepos < 0
      if @bytenew == 0xFF
        @data << 0xFF
        @data << 0x00
      else
        @data << @bytenew
      end
      @bytepos = 7
      @bytenew = 0
    end
  end
end

def dht_bytes
  data = [0x00]
  data += @std_dc_luminance_nrcodes[1..-1]
  data += @std_dc_luminance_values
  data << 0x10
  data += @std_ac_luminance_nrcodes[1..-1]
  data += @std_ac_luminance_values
  data << 0x01
  data += @std_dc_chrominance_nrcodes[1..-1]
  data += @std_dc_chrominance_values
  data << 0x11
  data += @std_ac_chrominance_nrcodes[1..-1]
  data += @std_ac_chrominance_values
  data.flatten
end

def compute_huffman_table(codes, table)
  code_value = 0
  pos_in_table = 0
  ht = []
  1.upto(16) do |k|
    1.upto(codes[k]) do
      ht[table[pos_in_table]] = []
      ht[table[pos_in_table]][0] = code_value
      ht[table[pos_in_table]][1] = k
      pos_in_table += 1
      code_value += 1
    end
    code_value *= 2
  end
  ht.map { |x| x.nil? ? 0 : x }
end

def init_tables
  @YDC_HT = compute_huffman_table(@std_dc_luminance_nrcodes, @std_dc_luminance_values)
  @UVDC_HT = compute_huffman_table(@std_dc_chrominance_nrcodes, @std_dc_chrominance_values)
  @YAC_HT = compute_huffman_table(@std_ac_luminance_nrcodes, @std_ac_luminance_values)
  @UVAC_HT = compute_huffman_table(@std_ac_chrominance_nrcodes, @std_ac_chrominance_values)
end

def initCategoryNumber
  @bitcode = Array.new(65535) { 0 }
  @category = Array.new(65535) { 0 }
  nrlower = 1
  nrupper = 2
  1.upto(15) do |cat|
    nrlower.upto(nrupper - 1) do |nr|
      @category[32767+nr] = cat
      @bitcode[32767+nr] = []
      @bitcode[32767+nr][1] = cat
      @bitcode[32767+nr][0] = nr
    end
    (-(nrupper - 1)).upto(nrlower) do |nrneg|
      @category[32767+nrneg] = cat
      @bitcode[32767+nrneg] = []
      @bitcode[32767+nrneg][1] = cat
      @bitcode[32767+nrneg][0] = nrupper-1+nrneg
    end
    nrlower <<= 1
    nrupper <<= 1
  end
end