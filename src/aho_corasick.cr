class AhoCorasick
  private def root
    @root
  end

  def initialize(dictionary)
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
      child_map[char]? || (suffix && (suffix as Node).search(char))
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
      failure = suffix as Node
      until failure.search(char) || failure.root?
        failure = failure.suffix as Node
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
