# -*- encoding: utf-8 -*-
# stub: rubocop-sequel 0.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "rubocop-sequel".freeze
  s.version = "0.4.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "default_lint_roller_plugin" => "RuboCop::Sequel::Plugin", "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Timoth\u00E9e Peignier".freeze]
  s.date = "2025-03-13"
  s.description = "Code style checking for Sequel".freeze
  s.email = ["timothee.peignier@tryphon.org".freeze]
  s.homepage = "https://github.com/rubocop/rubocop-sequel".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A Sequel plugin for RuboCop".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<lint_roller>.freeze, ["~> 1.1"])
  s.add_runtime_dependency(%q<rubocop>.freeze, [">= 1.72.1", "< 2"])
end
