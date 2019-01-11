class Node
  attr_accessor :weight, :symbol, :left, :right, :parent

  def initialize(params = {})
    @weight = params[:weight] || 0
    @symbol = params[:symbol] || ''
    @left   = params[:left]   || nil
    @right  = params[:right]  || nil
    @parent = params[:parent] || nil
  end

  def walk(&block)
    walk_node('', &block)
  end

  def walk_node(code, &block)
    yield(self, code)
    @left.walk_node(code + '0', &block) unless @left.nil?
    @right.walk_node(code + '1', &block) unless @right.nil?
  end

  def leaf?
    @symbol != ''
  end

  def internal?
    @symbol == ''
  end

  def root?
    internal? and @parent.nil?
  end
end