# -*- encoding: utf-8 -*-
# stub: digest-xxhash 0.2.9 ruby lib
# stub: ext/digest/xxhash/extconf.rb

Gem::Specification.new do |s|
  s.name = "digest-xxhash".freeze
  s.version = "0.2.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["konsolebox".freeze]
  s.date = "2024-12-30"
  s.description = "    This gem provides XXH32, XXH64, XXH3_64bits and XXH3_128bits\n    functionalities for Ruby.  It inherits Digest::Class and complies\n    with Digest::Instance's functional design.\n".freeze
  s.email = ["konsolebox@gmail.com".freeze]
  s.extensions = ["ext/digest/xxhash/extconf.rb".freeze]
  s.files = ["ext/digest/xxhash/extconf.rb".freeze]
  s.homepage = "https://github.com/konsolebox/digest-xxhash-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.2".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A Digest framework based XXHash library for Ruby".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake-compiler>.freeze, ["~> 1.2", ">= 1.2.3"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.8"])
end
