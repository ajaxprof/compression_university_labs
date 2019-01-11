require_relative 'binary_queue'
require_relative 'utils'
require_relative 'tables'

class JpegDecoder
  attr_accessor :components, :queue, :dc_tables, :ac_tables

  def initialize(sos_seg, dc_data, ac_data)
    @stream = sos_seg.payload.dup
    load_header
    decode(dc_data, ac_data)
  end

  def load_header
    @stream.shift(2)
    components_count = @stream.shift
    @components = []
    components_count.times do
      @components << {
        id: @stream.shift,
        dc_id: @stream[0] >> 4,
        ac_id: @stream[0] & 0x0F,
        stream: []
      }
      @stream.shift
    end
    @stream.shift(3)
  end

  def channels
    ys = @components.select { |com| com[:id] % 3 == 1 }.map { |com| com[:stream] }.flatten
    cbs = @components.select { |com| com[:id] % 3 == 2 }.map { |com| com[:stream] }.flatten
    crs = @components.select { |com| com[:id] % 3 == 0 }.map { |com| com[:stream] }.flatten
    lum_matrices = ys.each_slice(64).to_a
    cb_matrices = cbs.each_slice(64).to_a
    cr_matrices = crs.each_slice(64).to_a
    lum_matrices[0..-2].each_with_index do |flat_matrix, i|
      lum_matrices[i + 1][0] += flat_matrix[0]
    end
    cb_matrices[0..-2].each_with_index do |flat_matrix, i|
      cb_matrices[i + 1][0] += flat_matrix[0]
    end
    cr_matrices[0..-2].each_with_index do |flat_matrix, i|
      cr_matrices[i + 1][0] += flat_matrix[0]
    end
    lum_matrices.map! { |zigzag| unzigzagify(zigzag) }
    cb_matrices.map! { |zigzag| unzigzagify(zigzag) }
    cr_matrices.map! { |zigzag| unzigzagify(zigzag) }
    [lum_matrices, cb_matrices, cr_matrices]
  end

  def decode(dc_data, ac_data)
    begin
      @dc_tables = dc_data.tables
      @ac_tables = ac_data.tables
      rst_indices = @stream.each_index.select { |i| @stream[i] == 0xFF && @stream[i + 1] == 0x00 }
      rst_indices.reverse.each { |i| @stream.delete_at(i + 1) ; @stream.delete_at(i) }
      @queue = BinaryQueue.new(@stream)
      loop do
        @components.each do |component|
          stream = []
          lum = component[:id] % 3 == 1
          matrices_count = lum ? 4 : 1
          matrices_count.times do
            line = [read_dc(component)]
            loop do
              ac = read_ac(component)
              line += [0] * (64 - line.size) if ac == 0
              break if ac == 0
              line += [0] * ac[:zeroes]
              line << ac[:value]
              break if line.size >= 64
            end
            stream << line
          end
          component[:stream] += stream.flatten
        end
        rem = @queue.queue
        rem_length = @queue.queue_length
        rem_val = ((rem >> (32 - rem_length)) & ((1 << rem_length) - 1))
        @queue.next(6) if rem_val == 0x3F && rem_length == 6
        break if @queue.empty?
      end
    rescue StandardError
    end
  end

  def read_dc(component)
    val = read_base(@dc_tables, component[:dc_id])
    return 0 if val.zero?
    length = val
    val = @queue.next(length)
    justify(val, length)
  end

  def read_ac(component)
    val = read_base(@ac_tables, component[:ac_id])
    return 0 if val.zero?
    zeroes = val >> 4
    length = val & 0x0F
    val = @queue.next(length)
    val = justify(val, length)
    { zeroes: zeroes, value: val }
  end

  def read_base(tables, id)
    val = nil
    length = 0
    buffer = 0
    loop do
      buffer <<= 1
      buffer += @queue.next
      length += 1
      val = tables[id][[length, buffer]]
      break unless val.nil?
    end
    val
  end

  def justify(val, length)
    return val unless val < (1 << (length - 1))
    val - 2**length + 1
  end

end