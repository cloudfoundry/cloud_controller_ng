# -*- encoding: utf-8 -*-
# stub: loggregator_emitter 5.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "loggregator_emitter".freeze
  s.version = "5.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Pivotal".freeze]
  s.date = "2016-09-27"
  s.description = "Library to emit data to Loggregator".freeze
  s.email = ["cf-eng@pivotallabs.com".freeze]
  s.homepage = "https://www.github.com/cloudfoundry/loggregator_emitter".freeze
  s.licenses = ["Apache 2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Library to emit data to Loggregator".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<beefcake>.freeze, ["~> 1.0.0"])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.3"])
  s.add_development_dependency(%q<coveralls>.freeze, ["~> 0.8", ">= 0.8.14"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 2.14", ">= 2.14.1"])
  s.add_development_dependency(%q<timecop>.freeze, [">= 0"])
end
