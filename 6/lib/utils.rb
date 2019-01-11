def to_ycbcr(pixel)
  [
    0   + 0.299    * pixel[0] + 0.587    * pixel[1] + 0.114    * pixel[2],
    128 - 0.168736 * pixel[0] - 0.331264 * pixel[1] + 0.5      * pixel[2],
    128 + 0.5      * pixel[0] - 0.418688 * pixel[1] - 0.081312 * pixel[2],
  ].map(&:round).map { |component| component > 255 ? 255 : component }
end

def to_rgb(pixel)
  [
    pixel[0]                               + 1.402    * (pixel[2] - 128),
    pixel[0] - 0.344136 * (pixel[1] - 128) - 0.714136 * (pixel[2] - 128),
    pixel[0] + 1.772    * (pixel[1] - 128)
  ].map(&:round).map { |component| component > 255 ? 255 : component }
end

def rgb_matrices(y_matrix, cb_matrix, cr_matrix)
  r_matrix = Array.new(8) do |i|
    Array.new(8) do |j|
      [[(128 + y_matrix[i][j] + 1.402 * cr_matrix[i / 2][j / 2]).round, 255].min, 0].max
    end
  end
  g_matrix = Array.new(8) do |i|
    Array.new(8) do |j|
      [[(128 + y_matrix[i][j] - 0.344136 * cb_matrix[i / 2][j / 2] - 0.714136 * cr_matrix[i / 2][j / 2]).round, 255].min, 0].max
    end
  end
  b_matrix = Array.new(8) do |i|
    Array.new(8) do |j|
      [[(128 + y_matrix[i][j] + 1.772 * cb_matrix[i / 2][j / 2]).round, 255].min, 0].max
    end
  end
  [r_matrix, g_matrix, b_matrix]
end

def discrete_cosine_transform(components)
  centered_components = components.map { |row| row.map { |component| component - 128 }}
  dct_matrix = Array.new(8) { Array.new(8) { 0.0 }}
  sqrt_2 = 0.7071067811865475
  pi = 3.1415926535897
  8.times do |u|
    8.times do |v|
      au = u.zero? ? sqrt_2 : 1.0
      av = v.zero? ? sqrt_2 : 1.0
      8.times do |x|
        8.times do |y|
          dct_matrix[u][v] += centered_components[x][y] * Math.cos((2 * x + 1) * u * pi / 16) * Math.cos((2 * y + 1) * v * pi / 16)
        end
      end
      dct_matrix[u][v] *= 0.25 * au * av
    end
  end
  dct_matrix.map! { |row| row.map!(&:round) }
end

def reverse_discrete_cosine_transform(matrix)
  matrix = matrix.each_slice(8).to_a
  sqrt_2 = 0.7071067811865475
  pi = 3.1415926535897
  real_matrix = Array.new(8) { Array.new(8) { 0.0 }}
  8.times do |x|
    8.times do |y|
      8.times do |u|
        8.times do |v|
          cu = u.zero? ? sqrt_2 : 1.0
          cv = v.zero? ? sqrt_2 : 1.0
          real_matrix[y][x] += cu * cv * matrix[v][u] * Math.cos((2 * x + 1) * u * pi / 16) * Math.cos((2 * y + 1) * v * pi / 16)
        end
      end
      real_matrix[y][x] /= 4
    end
  end
  real_matrix.map! { |row| row.map!(&:round) }
end

def quantize(dct_matrix)
  require 'json'
  quantization_matrix = [3, 2, 2, 3, 4, 6, 8, 10, 2, 2, 2, 3, 4, 9, 10, 9, 2, 2, 3, 4, 6, 9, 11, 9, 2, 3, 4, 5, 8, 14, 13, 10, 3, 4, 6, 9, 11, 17, 16, 12, 4, 6, 9, 10, 13, 17, 18, 15, 8, 10, 12, 14, 16, 19, 19, 16, 12, 15, 15, 16, 18, 16, 16, 16].each_slice(8).to_a
  dct_matrix.each_with_index.map do |row, i|
    row.each_with_index.map do |component, j|
      (component / quantization_matrix[i][j]).round
    end
  end.map! { |row| row.map!(&:round) }
end

def zigzagify(matrix)
  shuffle = [0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63]
  flat_matrix = matrix.flatten
  shuffle.map { |i| flat_matrix[i] }
end

def unzigzagify(line)
  shuffle = [0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63]
  res = Array.new(64)
  64.times do |i|
    res[shuffle[i]] = line[i]
  end
  res
end