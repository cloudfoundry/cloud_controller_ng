# -*- encoding: utf-8 -*-
# stub: aliyun-sdk 0.8.0 ruby lib
# stub: ext/crcx/extconf.rb

Gem::Specification.new do |s|
  s.name = "aliyun-sdk".freeze
  s.version = "0.8.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Tianlong Wu".freeze]
  s.bindir = "lib/aliyun".freeze
  s.date = "2020-08-17"
  s.description = "A Ruby program to facilitate accessing Aliyun Object Storage Service".freeze
  s.email = ["rockuw.@gmail.com".freeze]
  s.extensions = ["ext/crcx/extconf.rb".freeze]
  s.extra_rdoc_files = ["README.md".freeze, "CHANGELOG.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "README.md".freeze, "ext/crcx/extconf.rb".freeze]
  s.homepage = "https://github.com/aliyun/aliyun-oss-ruby-sdk".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Aliyun OSS SDK for Ruby".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.6"])
  s.add_runtime_dependency(%q<rest-client>.freeze, ["~> 2.0"])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.10"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10.4"])
  s.add_development_dependency(%q<rake-compiler>.freeze, ["~> 0.9.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.3"])
  s.add_development_dependency(%q<webmock>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.10.0"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.8"])
end
