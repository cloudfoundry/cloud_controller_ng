# -*- encoding: utf-8 -*-
# stub: palm_civet 1.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "palm_civet".freeze
  s.version = "1.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Anand Gaitonde".freeze]
  s.bindir = "exe".freeze
  s.date = "2018-02-27"
  s.description = "A ruby port of github.com/cloudfoundry/bytefmt.".freeze
  s.homepage = "https://github.com/XenoPhex/palm_civet".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Human readable byte formatter.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.16"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
end
