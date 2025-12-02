# -*- encoding: utf-8 -*-
# stub: sequel_pg 1.17.2 ruby lib
# stub: ext/sequel_pg/extconf.rb

Gem::Specification.new do |s|
  s.name = "sequel_pg".freeze
  s.version = "1.17.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/jeremyevans/sequel_pg/issues", "changelog_uri" => "https://github.com/jeremyevans/sequel_pg/blob/master/CHANGELOG", "documentation_uri" => "https://github.com/jeremyevans/sequel_pg/blob/master/README.rdoc", "mailing_list_uri" => "https://github.com/jeremyevans/sequel_pg/discussions", "source_code_uri" => "https://github.com/jeremyevans/sequel_pg" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jeremy Evans".freeze]
  s.date = "2025-03-14"
  s.description = "sequel_pg overwrites the inner loop of the Sequel postgres\nadapter row fetching code with a C version.  The C version\nis significantly faster than the pure ruby version\nthat Sequel uses by default.\n\nsequel_pg also offers optimized versions of some dataset\nmethods, as well as adds support for using PostgreSQL\nstreaming.\n".freeze
  s.email = "code@jeremyevans.net".freeze
  s.extensions = ["ext/sequel_pg/extconf.rb".freeze]
  s.extra_rdoc_files = ["README.rdoc".freeze, "CHANGELOG".freeze, "MIT-LICENSE".freeze]
  s.files = ["CHANGELOG".freeze, "MIT-LICENSE".freeze, "README.rdoc".freeze, "ext/sequel_pg/extconf.rb".freeze]
  s.homepage = "http://github.com/jeremyevans/sequel_pg".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--quiet".freeze, "--line-numbers".freeze, "--inline-source".freeze, "--title".freeze, "sequel_pg: Faster SELECTs when using Sequel with pg".freeze, "--main".freeze, "README.rdoc".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Faster SELECTs when using Sequel with pg".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<pg>.freeze, [">= 0.18.0", "!= 1.2.0"])
  s.add_runtime_dependency(%q<sequel>.freeze, [">= 4.38.0"])
end
