# -*- encoding: utf-8 -*-
# stub: rspec_api_documentation 6.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rspec_api_documentation".freeze
  s.version = "6.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Chris Cahoon".freeze, "Sam Goldman".freeze, "Eric Oestrich".freeze]
  s.date = "2018-10-03"
  s.description = "Generate API docs from your test suite".freeze
  s.email = ["chris@smartlogicsolutions.com".freeze, "sam@smartlogicsolutions.com".freeze, "eric@smartlogicsolutions.com".freeze]
  s.homepage = "http://smartlogicsolutions.com".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A double black belt for your docs".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 3.0.0"])
  s.add_runtime_dependency(%q<mustache>.freeze, ["~> 1.0", ">= 0.99.4"])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<fakefs>.freeze, ["~> 0.4"])
  s.add_development_dependency(%q<sinatra>.freeze, ["~> 1.4", ">= 1.4.4"])
  s.add_development_dependency(%q<aruba>.freeze, ["~> 0.5"])
  s.add_development_dependency(%q<capybara>.freeze, ["~> 2.2"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.1"])
  s.add_development_dependency(%q<rack-test>.freeze, ["~> 0.6.2"])
  s.add_development_dependency(%q<rack-oauth2>.freeze, ["~> 1.2.2", ">= 1.0.7"])
  s.add_development_dependency(%q<webmock>.freeze, ["~> 1.7"])
  s.add_development_dependency(%q<rspec-its>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<faraday>.freeze, ["~> 0.9", ">= 0.9.0"])
  s.add_development_dependency(%q<thin>.freeze, ["~> 1.6", ">= 1.6.3"])
  s.add_development_dependency(%q<nokogiri>.freeze, ["~> 1.8", ">= 1.8.2"])
  s.add_development_dependency(%q<yard>.freeze, [">= 0.9.11"])
end
