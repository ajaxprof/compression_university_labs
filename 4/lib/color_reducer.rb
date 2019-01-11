require 'set'
require 'progress_bar'

def reduce_palette(palette)
  desired_size = 256
  pain = 1
  useless_rounds = 0
  reduced_palette = palette.dup
  loop do
    pain = useless_rounds + 1
    pixel = reduced_palette.sample
    most_similiar = find_most_similiar_exclusive(pixel, reduced_palette)
    if distance(pixel, most_similiar) < pain
      reduced_palette.reject!{ |x| x == pixel }
      useless_rounds = 0
    else
      useless_rounds += 1
    end  
    break if reduced_palette.size <= desired_size
  end
  reduced_palette
end

def reduce_pixels(pixels, palette)
  puts "               >>>>> reducing image pixels according to palette <<<<<"
  bar = ProgressBar.new(pixels.size)
  memo = {}
  pixels.map! do |pix1|
    bar.increment!
    memo.has_key?(pix1) ? memo[pix1] : memo[pix1] = palette.min_by{ |pix2| Math.sqrt(((pix1[0] - pix2[0]) * 0.299) ** 2 + ((pix1[1] - pix2[1]) * 0.587) ** 2 + ((pix1[2] - pix2[2]) * 0.114) ** 2) }
  end  
end

def distance(pix1, pix2)
  Math.sqrt(((pix1[0] - pix2[0]) * 0.3) * ((pix1[0] - pix2[0]) * 0.3) + ((pix1[1] - pix2[1]) * 0.59) * ((pix1[1] - pix2[1]) * 0.59) + ((pix1[2] - pix2[2]) * 0.11) * ((pix1[2] - pix2[2]) * 0.11))
end

def find_most_similiar(pixel, palette)
  palette.min_by{ |candidate| distance(candidate, pixel) }
end

def find_most_similiar_exclusive(pixel, palette)
  palette.reject{ |candidate| candidate == pixel }.sort_by{ |candidate| distance(pixel, candidate) }[0]
end