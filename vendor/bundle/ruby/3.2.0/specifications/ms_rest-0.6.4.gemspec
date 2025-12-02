# -*- encoding: utf-8 -*-
# stub: ms_rest 0.6.4 ruby lib

Gem::Specification.new do |s|
  s.name = "ms_rest".freeze
  s.version = "0.6.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Microsoft Corporation".freeze]
  s.date = "2017-04-04"
  s.description = "Azure Client Library for Ruby.".freeze
  s.email = "azsdkteam@microsoft.com".freeze
  s.homepage = "https://aka.ms/ms_rest".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Azure Client Library for Ruby.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.9"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.3"])
  s.add_runtime_dependency(%q<timeliness>.freeze, ["~> 0.3"])
  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<faraday>.freeze, ["~> 0.9"])
end
