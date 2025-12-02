# -*- encoding: utf-8 -*-
# stub: delayed_job 4.1.13 ruby lib

Gem::Specification.new do |s|
  s.name = "delayed_job".freeze
  s.version = "4.1.13"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/collectiveidea/delayed_job/issues", "changelog_uri" => "https://github.com/collectiveidea/delayed_job/blob/master/CHANGELOG.md", "source_code_uri" => "https://github.com/collectiveidea/delayed_job" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Brandon Keepers".freeze, "Brian Ryckbost".freeze, "Chris Gaffney".freeze, "David Genord II".freeze, "Erik Michaels-Ober".freeze, "Matt Griffin".freeze, "Steve Richert".freeze, "Tobias L\u00FCtke".freeze]
  s.date = "2024-11-08"
  s.description = "Delayed_job (or DJ) encapsulates the common pattern of asynchronously executing longer tasks in the background. It is a direct extraction from Shopify where the job table is responsible for a multitude of core tasks.".freeze
  s.email = ["brian@collectiveidea.com".freeze]
  s.homepage = "http://github.com/collectiveidea/delayed_job".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Database-backed asynchronous priority queue system -- Extracted from Shopify".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 3.0", "< 9.0"])
end
