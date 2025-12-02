# -*- encoding: utf-8 -*-
# stub: steno 1.3.5 ruby lib

Gem::Specification.new do |s|
  s.name = "steno".freeze
  s.version = "1.3.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["mpage".freeze]
  s.date = "2024-03-18"
  s.description = "A thread-safe logging library designed to support multiple log destinations.".freeze
  s.email = ["mpage@rbcon.com".freeze]
  s.executables = ["steno-prettify".freeze]
  s.files = ["bin/steno-prettify".freeze]
  s.homepage = "http://www.cloudfoundry.org".freeze
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A logging library.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<fluent-logger>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<yajl-ruby>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<rack-test>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.13.0"])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.62.0"])
  s.add_development_dependency(%q<rubocop-rake>.freeze, ["~> 0.6.0"])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 2.27.0"])
end
