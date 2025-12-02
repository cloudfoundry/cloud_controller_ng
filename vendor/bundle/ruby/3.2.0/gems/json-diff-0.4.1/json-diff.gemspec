$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'json-diff/version'

Gem::Specification.new do |s|
  s.name        = 'json-diff'
  s.license     = 'MIT'
  s.version     = JsonDiff::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Thaddée Tyl']
  s.email       = ['thaddee.tyl@gmail.com']
  s.homepage    = 'http://github.com/espadrine/json-diff'
  s.summary     = %q{Compute the difference between two JSON-serializable Ruby objects.}
  s.description = %q{Take two Ruby objects that can be serialized to JSON. Output an array of operations (additions, deletions, moves) that would convert the first one to the second one.}
  s.files       = `git ls-files`.split("\n")
  s.bindir      = "bin"
  s.executables = ["json-diff"]
end
