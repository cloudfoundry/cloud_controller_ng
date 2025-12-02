# -*- encoding: utf-8 -*-
# stub: allowy 2.1.0 ruby lib

Gem::Specification.new do |s|
  s.name = "allowy".freeze
  s.version = "2.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Dmytrii Nagirniak".freeze]
  s.date = "2015-01-06"
  s.description = "Allowy provides CanCan-like way of checking permission but doesn't enforce a tight DSL giving you more control".freeze
  s.email = ["dnagir@gmail.com".freeze]
  s.homepage = "https://github.com/dnagir/allowy".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Authorization with simplicity and explicitness in mind".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<i18n>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 3.2"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<its>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry>.freeze, [">= 0"])
  s.add_development_dependency(%q<guard>.freeze, [">= 0"])
  s.add_development_dependency(%q<guard-rspec>.freeze, [">= 0"])
end
