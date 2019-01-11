require_relative './node'

class NodeQueue
  attr_accessor :nodes, :root

  def initialize(string)
    @rating = string.chars.reduce({}){ |h, k| h[k] = h[k].to_i + 1; h }
    @nodes = []
    @rating.each do |c, w|
      @nodes << Node.new(:symbol => c, :weight => w)
    end
    generate_tree
  end

  def generate_tree
    while @nodes.size > 1
      sorted = @nodes.sort{ |a, b| a.weight <=> b.weight }
      to_merge = []
      2.times { to_merge << sorted.shift }
      sorted << merge_nodes(to_merge[0], to_merge[1])
      @nodes = sorted
    end
    @root = @nodes.first
  end

  def merge_nodes(node1, node2)
    left = node1.weight > node2.weight ? node2 : node1
    right = left == node1 ? node2 : node1
    node = Node.new(:weight => left.weight + right.weight, :left => left, :right => right)
    left.parent = right.parent = node
    node
  end
end