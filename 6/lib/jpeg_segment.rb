class JpegSegment
  attr_accessor :type, :payload

  def initialize(stream)
    marker = stream[0..1]
    raise 'invalid marker' unless MARKERS.key?(marker)
    @type = MARKERS[marker]
    @payload = read_payload(stream[2..-1]) if PAYLOAD_MARKERS.include?(@type)
  end

  def self.raw_data(marker, payload = nil)
    data = MARKERS.invert[marker].dup
    data << ((payload.length + 2) / 0x100) unless payload.nil?
    data << ((payload.length + 2) & 0xFF) unless payload.nil?
    data << payload unless payload.nil?
    data.flatten
  end

  def length
    return 2 if @payload.nil?
    2 + @payload.length
  end

  def read_payload(stream)
    length = (stream[0] << 8) + stream[1]
    length = stream.length - 2 if @type == :SOS
    stream[0..length - 1]
  end

  MARKERS = {
    SOI: [0xFF, 0xD8],
    SOF0: [0xFF, 0xC0],
    SOF2: [0xFF, 0xC2],
    DHT: [0xFF, 0xC4],
    DQT: [0xFF, 0xDB],
    DRI: [0xFF, 0xDD],
    SOS: [0xFF, 0xDA],
    RST0: [0xFF, 0xD0],
    RST1: [0xFF, 0xD1],
    RST2: [0xFF, 0xD2],
    RST3: [0xFF, 0xD3],
    RST4: [0xFF, 0xD4],
    RST5: [0xFF, 0xD5],
    RST6: [0xFF, 0xD6],
    RST7: [0xFF, 0xD7],
    APP0: [0xFF, 0xE0],
    APP1: [0xFF, 0xE1],
    APP2: [0xFF, 0xE2],
    APP3: [0xFF, 0xE3],
    APP4: [0xFF, 0xE4],
    APP5: [0xFF, 0xE5],
    APP6: [0xFF, 0xE6],
    APP7: [0xFF, 0xE7],
    APP8: [0xFF, 0xE8],
    APP9: [0xFF, 0xE9],
    APP10: [0xFF, 0xEA],
    APP11: [0xFF, 0xEB],
    APP12: [0xFF, 0xEC],
    APP13: [0xFF, 0xED],
    APP14: [0xFF, 0xEE],
    APP15: [0xFF, 0xEF],
    COM: [0xFF, 0xFE],
    EOI: [0xFF, 0xD9]
  }.invert.freeze

  PAYLOAD_MARKERS = %i[SOF0 SOF2 DHT DQT DRI SOS APP0 APP1
                       APP2 APP3 APP4 APP5 APP6 APP7 APP8 APP9
                       APP10 APP11 APP12 APP13 APP14 APP15 COM].freeze
end