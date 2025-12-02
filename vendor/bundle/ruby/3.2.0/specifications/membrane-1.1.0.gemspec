# -*- encoding: utf-8 -*-
# stub: membrane 1.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "membrane".freeze
  s.version = "1.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["mpage".freeze]
  s.date = "2014-04-03"
  s.description = "      Membrane provides an easy to use DSL for specifying validation\n      logic declaratively.\n".freeze
  s.email = ["support@cloudfoundry.org".freeze]
  s.homepage = "http://www.cloudfoundry.org".freeze
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A DSL for validating data.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<ci_reporter>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
end
