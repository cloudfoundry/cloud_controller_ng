# -*- encoding: utf-8 -*-
# stub: newrelic_rpm 9.23.0 ruby lib

Gem::Specification.new do |s|
  s.name = "newrelic_rpm".freeze
  s.version = "9.23.0"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/newrelic/newrelic-ruby-agent/issues", "changelog_uri" => "https://github.com/newrelic/newrelic-ruby-agent/blob/main/CHANGELOG.md", "documentation_uri" => "https://docs.newrelic.com/docs/agents/ruby-agent", "homepage_uri" => "https://newrelic.com/ruby", "source_code_uri" => "https://github.com/newrelic/newrelic-ruby-agent" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Tanna McClure".freeze, "Kayla Reopelle".freeze, "Hannah Ramadan".freeze]
  s.date = "1980-01-02"
  s.description = "New Relic is a performance management system, developed by New Relic,\nInc (http://www.newrelic.com).  New Relic provides you with deep\ninformation about the performance of your web application as it runs\nin production. The New Relic Ruby agent is dual-purposed as a either a\nGem or plugin, hosted on\nhttps://github.com/newrelic/newrelic-ruby-agent/\n".freeze
  s.email = "support@newrelic.com".freeze
  s.executables = ["newrelic".freeze, "newrelic_rpm".freeze, "nrdebug".freeze]
  s.extra_rdoc_files = ["CHANGELOG.md".freeze, "CONTRIBUTING.md".freeze, "LICENSE".freeze, "README.md".freeze, "newrelic.yml".freeze]
  s.files = ["CHANGELOG.md".freeze, "CONTRIBUTING.md".freeze, "LICENSE".freeze, "README.md".freeze, "bin/newrelic".freeze, "bin/newrelic_rpm".freeze, "bin/nrdebug".freeze, "newrelic.yml".freeze]
  s.homepage = "https://github.com/newrelic/newrelic-ruby-agent".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.4.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "New Relic Ruby Agent".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
  s.add_development_dependency(%q<minitest>.freeze, ["= 5.3.3"])
  s.add_development_dependency(%q<minitest-stub-const>.freeze, ["= 0.6"])
  s.add_development_dependency(%q<mocha>.freeze, ["~> 1.16"])
  s.add_development_dependency(%q<mutex_m>.freeze, [">= 0"])
  s.add_development_dependency(%q<ostruct>.freeze, [">= 0"])
  s.add_development_dependency(%q<rack>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake>.freeze, ["= 12.3.3"])
  s.add_development_dependency(%q<rubocop>.freeze, ["= 1.57.2"])
  s.add_development_dependency(%q<rubocop-ast>.freeze, ["= 1.28.1"])
  s.add_development_dependency(%q<rubocop-minitest>.freeze, ["= 0.27.0"])
  s.add_development_dependency(%q<rubocop-performance>.freeze, ["= 1.16.0"])
  s.add_development_dependency(%q<rubocop-rake>.freeze, ["= 0.6.0"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
  s.add_development_dependency(%q<warning>.freeze, [">= 0"])
  s.add_development_dependency(%q<yard>.freeze, [">= 0"])
end
