# -*- encoding: utf-8 -*-
# stub: json-diff 0.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "json-diff".freeze
  s.version = "0.4.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Thadd\u00E9e Tyl".freeze]
  s.date = "2017-05-04"
  s.description = "Take two Ruby objects that can be serialized to JSON. Output an array of operations (additions, deletions, moves) that would convert the first one to the second one.".freeze
  s.email = ["thaddee.tyl@gmail.com".freeze]
  s.executables = ["json-diff".freeze]
  s.files = ["bin/json-diff".freeze]
  s.homepage = "http://github.com/espadrine/json-diff".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Compute the difference between two JSON-serializable Ruby objects.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version
end
