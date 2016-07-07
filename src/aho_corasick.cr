require "json"

class AhoCorasick
  private def root
    @root
  end

  private def collect_nodes(node : Node, ret : Array(Node) = [] of Node)
    ret << node
    node.child_map.each do |char, child|
      collect_nodes(child, ret)
    end
    return ret
  end

  def to_json(io)
    nodes = collect_nodes(@root)
    node_to_idx = {} of Node => Int32
    nodes.each_with_index { |n, idx| node_to_idx[n] = idx }
    io << "["
    nodes.each_with_index do |n, idx|
      suffix = n.suffix
      parent = n.parent
      parent_idx = parent ? node_to_idx[parent] : -1
      suffix_idx = suffix ? node_to_idx[suffix] : -1
      child_map = {} of Char => Int32
      n.child_map.each do |char, child|
        child_map[char] = node_to_idx[child]
      end
      io << "{\"pa\":#{parent_idx},\"sx\":#{suffix_idx},\"mt\":"
      n.matches.to_json io
      io << ",\"mp\":"
      child_map.to_json io
      io << "}"
      if idx + 1 != nodes.size
        io << ","
      end
    end
    io << "]"
  end

  def self.from_json(s)
    js = JSON.parse s
    nodes = [] of Node
    parent_map = {} of Tuple(Node, Char) => Int32
    suffix_map = {} of Node => Int32
    js.each do |n|
      parent_idx = n["pa"].as_i
      suffix_idx = n["sx"].as_i
      parent = parent_idx < 0 ? nil : nodes[parent_idx]
      node = Node.new parent
      nodes << node
      n["mt"].as_a.each do |m|
        node.matches << m.as(Int64).to_i32
      end
      n["mp"].each do |char, child_idx|
        parent_map[{node, char.as_s[0]}] = child_idx.as_i
      end
      if suffix_idx >= 0
        suffix_map[node] = suffix_idx
      end
    end
    parent_map.each do |k, v|
      node, char = k
      node.child_map[char] = nodes[v]
    end
    suffix_map.each do |node, v|
      node.suffix = nodes[v]
    end
    return AhoCorasick.new nodes[0]
  end

  def initialize(root : Node)
    @root = root
  end

  def initialize(dictionary : Array(String))
    @root = Node.new

    build_trie(dictionary)
    build_suffix_map
  end

  def match(string : String)
    idx = -1
    string.each_char.reduce(root) do |node, char|
      idx += 1
      child = (node || root).search(char)
      next unless child
      child.matches.each do |m|
        yield idx, m
      end
      child
    end
  end

  private def build_trie(dictionary)
    dictionary.each_with_index do |string, idx|
      string.each_char.reduce(root) do |node, char|
        node.child_or_create(char)
      end.matches << idx
    end
  end

  def build_suffix_map
    queue = [] of Node

    root.children.each do |child|
      child.suffix = root
      queue << child
    end

    until queue.empty?
      node = queue.delete_at 0
      node.children.each { |child| queue << child }
      node.build_child_suffixes
    end
  end

  class Node
    @suffix : Node?
    getter :matches, :child_map, :parent
    property :suffix

    def initialize(parent : (Node | Nil) = nil)
      @matches = [] of Int32
      @child_map = {} of Char => Node
      @parent = parent
    end

    def search(char : Char) : (Node | Nil)
      child_map[char]? || (suffix && (suffix.as(Node)).search(char))
    end

    def child_or_create(char)
      child_map[char] ||= self.class.new(self)
    end

    def children
      child_map.values
    end

    def root?
      !parent
    end

    def build_child_suffixes
      child_map.each do |char, child|
        failure = find_failure_node(char)
        child_suffix = failure.search(char)

        if child_suffix
          child.suffix = child_suffix
          child.matches.concat(child_suffix.matches)
        elsif failure.root?
          child.suffix = failure
        end
      end
    end

    def find_failure_node(char : Char)
      failure = suffix.as(Node)
      until failure.search(char) || failure.root?
        failure = failure.suffix.as(Node)
      end

      failure
    end

    def to_s
      <<-STR
{
"child_map": {#{@child_map.map { |k, v| "\"#{k}\": #{v.to_s}" }.join(",")}},
"matches": #{@matches}
}
STR
    end
  end
end
