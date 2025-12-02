# -*- encoding: utf-8 -*-
# stub: rspec-wait 1.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "rspec-wait".freeze
  s.version = "1.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "bug_tracker_uri" => "https://github.com/laserlemon/rspec-wait/issues", "funding_uri" => "https://github.com/sponsors/laserlemon", "homepage_uri" => "https://github.com/laserlemon/rspec-wait", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/laserlemon/rspec-wait" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Steve Richert".freeze]
  s.date = "1980-01-02"
  s.description = "RSpec::Wait enables time-resilient expectations in your RSpec test suite.".freeze
  s.email = "steve.richert@hey.com".freeze
  s.extra_rdoc_files = ["README.md".freeze]
  s.files = ["README.md".freeze]
  s.homepage = "https://github.com/laserlemon/rspec-wait".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Time-resilient expectations in RSpec".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rspec>.freeze, [">= 3.4"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 2.0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 13.0"])
end
