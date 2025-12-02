$:.push File.expand_path("../lib", __FILE__)
require 'multipart_parser/version'

Gem::Specification.new do |s|
  s.name        = 'multipart-parser'
  s.version     = MultipartParser::VERSION
  s.authors     = ['Daniel Abrahamsson']
  s.email       = ['hamsson@gmail.com']
  s.homepage    = 'https://github.com/danabr/multipart-parser'
  s.summary     = %q{simple parser for multipart MIME messages}
  s.description = <<-DESCRIPTION.gsub(/^ */, '')
    multipart-parser is a simple parser for multipart MIME messages, written in
    Ruby, based on felixge/node-formidable's parser.

    Some things to note:
      - Pure Ruby
      - Event-driven API
      - Only supports one level of multipart parsing. Invoke another parser if
        you need to handle nested messages.
      - Does not perform I/O.
      - Does not depend on any other library.
  DESCRIPTION

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']
end
