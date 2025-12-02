# -*- encoding: utf-8 -*-
# stub: fluent-logger 0.10.0 ruby lib

Gem::Specification.new do |s|
  s.name = "fluent-logger".freeze
  s.version = "0.10.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sadayuki Furuhashi".freeze]
  s.date = "1980-01-02"
  s.description = "fluent logger for ruby".freeze
  s.email = "frsyuki@gmail.com".freeze
  s.executables = ["fluent-post".freeze]
  s.files = ["bin/fluent-post".freeze]
  s.homepage = "https://github.com/fluent/fluent-logger-ruby".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "fluent logger for ruby".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<msgpack>.freeze, [">= 1.0.0", "< 2"])
  s.add_runtime_dependency(%q<logger>.freeze, ["~> 1.6"])
end
