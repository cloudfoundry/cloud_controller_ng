# -*- encoding: utf-8 -*-
# stub: codeclimate-test-reporter 1.0.9 ruby lib

Gem::Specification.new do |s|
  s.name = "codeclimate-test-reporter".freeze
  s.version = "1.0.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Bryan Helmkamp".freeze, "Code Climate".freeze]
  s.date = "2018-10-08"
  s.description = "Collects test coverage data from your Ruby test suite and sends it to Code Climate's hosted, automated code review service. Based on SimpleCov.".freeze
  s.email = ["bryan@brynary.com".freeze, "hello@codeclimate.com".freeze]
  s.executables = ["cc-tddium-post-worker".freeze, "codeclimate-test-reporter".freeze]
  s.files = ["bin/cc-tddium-post-worker".freeze, "bin/codeclimate-test-reporter".freeze]
  s.homepage = "https://github.com/codeclimate/ruby-test-reporter".freeze
  s.licenses = ["MIT".freeze]
  s.post_install_message = "\n  Code Climate's codeclimate-test-reporter gem has been deprecated in favor of\n  our language-agnostic unified test reporter. The new test reporter is faster,\n  distributed as a static binary so dependency conflicts never occur, and\n  supports parallelized CI builds & multi-language CI configurations.\n\n  Please visit https://docs.codeclimate.com/v1.0/docs/configuring-test-coverage\n  for help setting up your CI process with our new test reporter.\n  ".freeze
  s.required_ruby_version = Gem::Requirement.new(">= 1.9".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Uploads Ruby test coverage data to Code Climate.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<simplecov>.freeze, ["<= 0.13"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<webmock>.freeze, [">= 0"])
end
