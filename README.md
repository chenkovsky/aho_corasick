# aho_corasick

AhoCorasick algorithm for crystal-lang

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  aho_corasick:
    github: chenkovsky/aho_corasick
```


## Usage


```crystal
require "aho_corasick"
matcher = AhoCorasick.new %w(a ab bc)
matched = [] of Tuple(Int32, Int32)
matcher.match("abcde") do |last_pos, pat_idx|
  matched << ({last_pos, pat_idx})
end
matched.should eq([{0, 0}, {1, 1}, {2, 2}])
```




## Contributing

1. Fork it ( https://github.com/chenkovsky/aho_corasick/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [chenkovsky](https://github.com/chenkovsky) chenkovsky - creator, maintainer
