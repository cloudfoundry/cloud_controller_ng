# -*- encoding: utf-8 -*-
# stub: fog-aws 3.33.1 ruby lib

Gem::Specification.new do |s|
  s.name = "fog-aws".freeze
  s.version = "3.33.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/fog/fog-aws/blob/master/CHANGELOG.md" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Josh Lane".freeze, "Wesley Beary".freeze]
  s.date = "1980-01-02"
  s.description = "This library can be used as a module for `fog` or as standalone provider\n                        to use the Amazon Web Services in applications..".freeze
  s.email = ["me@joshualane.com".freeze, "geemus@gmail.com".freeze]
  s.homepage = "https://github.com/fog/fog-aws".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Module for the 'fog' gem to support Amazon Web Services.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<benchmark>.freeze, [">= 0"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<github_changelog_generator>.freeze, ["~> 1.16"])
  s.add_development_dependency(%q<rake>.freeze, [">= 12.3.3"])
  s.add_development_dependency(%q<rubyzip>.freeze, ["~> 3.0.0"])
  s.add_development_dependency(%q<shindo>.freeze, ["~> 0.3"])
  s.add_runtime_dependency(%q<base64>.freeze, [">= 0.2", "< 0.4"])
  s.add_runtime_dependency(%q<fog-core>.freeze, ["~> 2.6"])
  s.add_runtime_dependency(%q<fog-json>.freeze, ["~> 1.1"])
  s.add_runtime_dependency(%q<fog-xml>.freeze, ["~> 0.1"])
end
