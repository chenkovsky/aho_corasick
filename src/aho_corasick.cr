require "json"

class AhoCorasick
  struct MatchList
    getter :elem, :next_

    def initialize(@elem : Int32, @next_ : Int32)
    end

    JSON.mapping(
      elem: Int32,
      next_: Int32
    )
  end

  struct AhoJSON
    JSON.mapping(
      chs: String,
      pa: Array(Int32),
      sx: Array(Int32),
      ml: Array(Int32),
      cl: Array(Int32),
      sb: Array(Int32),
      ms: Array(MatchList),
      rt: Int32
    )

    def initialize(@chs : String,
                   @pa : Array(Int32),
                   @sx : Array(Int32),
                   @ml : Array(Int32),
                   @cl : Array(Int32),
                   @sb : Array(Int32),
                   @ms : Array(MatchList),
                   @rt : Int32)
    end
  end

  alias Rel = {elem: Int32, char: Char}

  def create_node(char : Char, parent : Int32 = -1, suffix : Int32 = -1, match_list : Int32 = -1, child_list : Int32 = -1, sibling : Int32 = -1)
    node_idx = @char.size
    @char << char
    @parent << parent
    @suffix << suffix
    @match_list << match_list
    @child_list << child_list
    @sibling << sibling
    return node_idx
  end

  def to_json(io)
    str = String.build do |s|
      @char.each do |x|
        s << x
      end
    end
    js = AhoJSON.new chs: str, pa: @parent, sx: @suffix, ml: @match_list, cl: @child_list, sb: @sibling, ms: @matches, rt: @root_idx
    js.to_json io
  end

  def self.from_json(str)
    js = AhoJSON.from_json(str)
    return AhoCorasick.new js
  end

  @root_idx : Int32
  @char : Array(Char)
  @parent : Array(Int32)
  @suffix : Array(Int32)
  @match_list : Array(Int32)
  @child_list : Array(Int32)
  @sibling : Array(Int32)

  def initialize(js : AhoJSON)
    @char = js.chs.chars
    @parent = js.pa
    @suffix = js.sx
    @match_list = js.ml
    @child_list = js.cl
    @sibling = js.sb
    @matches = js.ms
    @root_idx = js.rt
    @child_map = Hash(Rel, Int32).new(initial_capacity: @child_list.size)
    @parent.each_with_index do |parent_idx, node_idx|
      if parent_idx >= 0
        @child_map[{elem: parent_idx, char: @char[node_idx]}] = node_idx
      end
    end
  end

  def initialize(dictionary : Array(String))
    arr_init_size = dictionary.size * 4
    @parent = Array(Int32).new arr_init_size
    @char = Array(Char).new arr_init_size
    @suffix = Array(Int32).new arr_init_size
    @match_list = Array(Int32).new arr_init_size
    @child_list = Array(Int32).new arr_init_size
    @sibling = Array(Int32).new arr_init_size

    @matches = Array(MatchList).new arr_init_size
    @child_map = Hash(Rel, Int32).new(initial_capacity: dictionary.size*4)
    @root_idx = create_node(char: '\0')
    build_trie(dictionary)
    build_suffix_map
  end

  def match(string : String)
    idx = -1
    string.each_char.reduce(@root_idx) do |node_idx, char|
      idx += 1
      cur_node_idx = @root_idx
      if node_idx >= 0
        cur_node_idx = node_idx
      end
      child = search(cur_node_idx, char)
      unless child >= 0
        -1
      else
        match_list = @match_list[child]
        while match_list >= 0
          yield idx, @matches[match_list].elem
          match_list = @matches[match_list].next_
        end
        child
      end
    end
  end

  private def build_trie(dictionary)
    dictionary.each_with_index do |string, idx|
      tail_idx = string.each_char.reduce(@root_idx) do |node_idx, char|
        child_or_create(node_idx, char)
      end
      add_match tail_idx, idx
    end
  end

  private def add_match(node_idx : Int32, elem : Int32)
    next_ = @match_list[node_idx]
    m = MatchList.new elem, next_
    m_idx = @matches.size
    @matches << m
    @match_list[node_idx] = m_idx
  end

  private def child_or_create(node_idx : Int32, char : Char) : Int32
    key = {elem: node_idx, char: char}
    if @child_map.has_key? key
      return @child_map[key]
    end
    prev_child_list = @child_list[node_idx]
    child_idx = create_node char, node_idx, -1, -1, -1, prev_child_list
    @child_list[node_idx] = child_idx
    @child_map[key] = child_idx
    return child_idx
  end

  def build_suffix_map
    queue = Array(Int32).new @char.size # node_idx queue
    queue_idx = 0
    child = @child_list[@root_idx]
    while child >= 0
      @suffix[child] = @root_idx
      queue << child
      child = @sibling[child]
    end

    until queue.size <= queue_idx
      node_idx = queue[queue_idx]
      queue_idx += 1
      child = @child_list[node_idx]
      while child >= 0
        queue << child
        child = @sibling[child]
      end
      build_child_suffixes node_idx
    end
  end

  def find_failure_node(node_idx : Int32, char : Char) : Int32
    failure_idx = @suffix[node_idx]
    until search(failure_idx, char) >= 0 || failure_idx == @root_idx
      failure_idx = @suffix[failure_idx]
    end
    failure_idx
  end

  def search(node_idx : Int32, char : Char) : Int32
    key = {elem: node_idx, char: char}
    suffix = @suffix[node_idx]
    ret = @child_map[key]?
    if !ret.nil?
      return ret
    end
    if suffix >= 0
      return search(suffix, char)
    end
    return -1
  end

  def merge_matches(node_idx : Int32, suffix_idx : Int32)
    match = @match_list[suffix_idx]
    prev_new_match = @match_list[node_idx]
    while match >= 0
      match_node = @matches[match]
      new_match_node = MatchList.new match_node.elem, prev_new_match
      prev_new_match = @matches.size
      @matches << new_match_node
      match = match_node.next_
    end
    @match_list[node_idx] = prev_new_match
  end

  def build_child_suffixes(node_idx : Int32)
    child = @child_list[node_idx]
    while child >= 0
      char = @char[child]

      failure_idx = find_failure_node(node_idx, char)
      child_suffix = search(failure_idx, char)

      if child_suffix >= 0
        @suffix[child] = child_suffix
        merge_matches(child, child_suffix)
      else
        @suffix[child] = failure_idx
      end
      child = @sibling[child]
    end
  end
end
