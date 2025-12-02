# -*- encoding: utf-8 -*-
# stub: mock_redis 0.53.0 ruby lib

Gem::Specification.new do |s|
  s.name = "mock_redis".freeze
  s.version = "0.53.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/sds/mock_redis/issues", "changelog_uri" => "https://github.com/sds/mock_redis/blob/v0.53.0/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/mock_redis/0.53.0", "homepage_uri" => "https://github.com/sds/mock_redis", "source_code_uri" => "https://github.com/sds/mock_redis/tree/v0.53.0" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Shane da Silva".freeze, "Samuel Merritt".freeze]
  s.date = "2025-11-08"
  s.description = "Instantiate one with `redis = MockRedis.new` and treat it like you would a normal Redis object. It supports all the usual Redis operations.".freeze
  s.email = ["shane@dasilva.io".freeze]
  s.homepage = "https://github.com/sds/mock_redis".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Redis mock that just lives in memory; useful for testing.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<redis>.freeze, ["~> 5"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
  s.add_development_dependency(%q<rspec-its>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<timecop>.freeze, ["~> 0.9.1"])
end
