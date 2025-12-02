# -*- encoding: utf-8 -*-
# stub: multipart-parser 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "multipart-parser".freeze
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Daniel Abrahamsson".freeze]
  s.date = "2012-08-22"
  s.description = "multipart-parser is a simple parser for multipart MIME messages, written in\nRuby, based on felixge/node-formidable's parser.\n\nSome things to note:\n- Pure Ruby\n- Event-driven API\n- Only supports one level of multipart parsing. Invoke another parser if\nyou need to handle nested messages.\n- Does not perform I/O.\n- Does not depend on any other library.\n".freeze
  s.email = ["hamsson@gmail.com".freeze]
  s.homepage = "https://github.com/danabr/multipart-parser".freeze
  s.rubygems_version = "3.4.19".freeze
  s.summary = "simple parser for multipart MIME messages".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version
end
