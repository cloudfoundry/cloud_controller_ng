# -*- encoding: utf-8 -*-
# stub: cloudfront-signer 3.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "cloudfront-signer".freeze
  s.version = "3.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Anthony Bouch".freeze, "Leonel Galan".freeze]
  s.date = "2017-06-22"
  s.description = "A gem to sign url and stream paths for Amazon CloudFront private content. Includes specific signing methods for both url and streaming paths, including html 'safe' escaped versions of each.".freeze
  s.email = ["tony@58bits.com".freeze, "leonelgalan@gmail.com".freeze]
  s.homepage = "http://github.com/leonelgalan/cloudfront-signer".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A gem to sign url and stream paths for Amazon CloudFront private content.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.5"])
  s.add_development_dependency(%q<codeclimate-test-reporter>.freeze, [">= 1.0"])
end
