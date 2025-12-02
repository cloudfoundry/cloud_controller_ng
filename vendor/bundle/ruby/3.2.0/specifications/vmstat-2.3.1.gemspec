# -*- encoding: utf-8 -*-
# stub: vmstat 2.3.1 ruby lib
# stub: ext/vmstat/extconf.rb

Gem::Specification.new do |s|
  s.name = "vmstat".freeze
  s.version = "2.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Vincent Landgraf".freeze]
  s.date = "2019-02-06"
  s.description = "\n    A focused and fast library to gather memory, \n    cpu, network, load avg and disk information\n  ".freeze
  s.email = ["vilandgr@googlemail.com".freeze]
  s.extensions = ["ext/vmstat/extconf.rb".freeze]
  s.files = ["ext/vmstat/extconf.rb".freeze]
  s.homepage = "http://threez.github.com/ruby-vmstat/".freeze
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A focused and fast library to gather system information".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, ["~> 11.3"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 2.9"])
  s.add_development_dependency(%q<rake-compiler>.freeze, [">= 0"])
  s.add_development_dependency(%q<guard-rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<timecop>.freeze, [">= 0"])
end
