# -*- encoding: utf-8 -*-
# stub: fog-core 2.6.0 ruby lib

Gem::Specification.new do |s|
  s.name = "fog-core".freeze
  s.version = "2.6.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/fog/fog-core/blob/master/changelog.md", "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Evan Light".freeze, "Wesley Beary".freeze]
  s.date = "2024-10-25"
  s.description = "Shared classes and tests for fog providers and services.".freeze
  s.email = ["evan@tripledogdare.net".freeze, "geemus@gmail.com".freeze]
  s.homepage = "https://github.com/fog/fog-core".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Shared classes and tests for fog providers and services.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<builder>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<excon>.freeze, ["~> 1.0"])
  s.add_runtime_dependency(%q<formatador>.freeze, [">= 0.2", "< 2.0"])
  s.add_runtime_dependency(%q<mime-types>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest-stub-const>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop-minitest>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop-rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<thor>.freeze, [">= 0"])
  s.add_development_dependency(%q<tins>.freeze, [">= 0"])
  s.add_development_dependency(%q<yard>.freeze, [">= 0"])
end
