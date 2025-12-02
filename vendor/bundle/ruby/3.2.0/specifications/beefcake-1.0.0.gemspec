# -*- encoding: utf-8 -*-
# stub: beefcake 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "beefcake".freeze
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Blake Mizerany".freeze, "Matt Proud".freeze, "Bryce Kerley".freeze]
  s.date = "2014-09-05"
  s.description = "A sane protobuf library for Ruby".freeze
  s.email = ["blake.mizerany@gmail.com".freeze, "matt.proud@gmail.com".freeze, "bkerley@brycekerley.net".freeze]
  s.executables = ["protoc-gen-beefcake".freeze]
  s.files = ["bin/protoc-gen-beefcake".freeze]
  s.homepage = "https://github.com/protobuf-ruby/beefcake".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A sane protobuf library for Ruby".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, ["~> 10.1.0"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.3"])
end
