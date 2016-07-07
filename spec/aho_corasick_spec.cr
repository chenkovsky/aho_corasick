require "./spec_helper"

describe AhoCorasick do
  it "works" do
    matcher = AhoCorasick.new %w(我 我是 是中)
    matched = [] of Tuple(Int32, Int32)
    matcher.match("我是中国人") do |last_pos, pat_idx|
      matched << ({last_pos, pat_idx})
    end
    matched.should eq([{0, 0}, {1, 1}, {2, 2}])
    s = matcher.to_json
    STDERR.puts s
    matcher = AhoCorasick.from_json s
    matched = [] of Tuple(Int32, Int32)
    matcher.match("我是中国人") do |last_pos, pat_idx|
      matched << ({last_pos, pat_idx})
    end
    matched.should eq([{0, 0}, {1, 1}, {2, 2}])
  end
end
