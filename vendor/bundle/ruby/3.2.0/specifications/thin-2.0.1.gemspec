# -*- encoding: utf-8 -*-
# stub: thin 2.0.1 ruby lib
# stub: ext/thin_parser/extconf.rb

Gem::Specification.new do |s|
  s.name = "thin".freeze
  s.version = "2.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/macournoyer/thin/blob/master/CHANGELOG", "source_code_uri" => "https://github.com/macournoyer/thin" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Marc-Andre Cournoyer".freeze]
  s.date = "1980-01-02"
  s.email = "macournoyer@gmail.com".freeze
  s.executables = ["thin".freeze]
  s.extensions = ["ext/thin_parser/extconf.rb".freeze]
  s.files = ["bin/thin".freeze, "ext/thin_parser/extconf.rb".freeze]
  s.homepage = "https://github.com/macournoyer/thin".freeze
  s.licenses = ["GPL-2.0-or-later".freeze, "Ruby".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.6".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A thin and fast web server".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rack>.freeze, [">= 1", "< 4"])
  s.add_runtime_dependency(%q<eventmachine>.freeze, ["~> 1.0", ">= 1.0.4"])
  s.add_runtime_dependency(%q<daemons>.freeze, ["~> 1.0", ">= 1.0.9"])
  s.add_runtime_dependency(%q<logger>.freeze, [">= 0"])
end
