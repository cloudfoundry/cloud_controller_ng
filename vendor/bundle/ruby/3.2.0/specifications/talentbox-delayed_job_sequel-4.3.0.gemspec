# -*- encoding: utf-8 -*-
# stub: talentbox-delayed_job_sequel 4.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "talentbox-delayed_job_sequel".freeze
  s.version = "4.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Jonathan Tron".freeze]
  s.date = "2017-11-27"
  s.description = "Sequel backend for DelayedJob, originally authored by Tobias Luetke".freeze
  s.email = ["jonathan@tron.name".freeze]
  s.extra_rdoc_files = ["README.md".freeze]
  s.files = ["README.md".freeze]
  s.homepage = "http://github.com/TalentBox/delayed_job_sequel".freeze
  s.rdoc_options = ["--main".freeze, "README.md".freeze, "--inline-source".freeze, "--line-numbers".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Sequel backend for DelayedJob".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<sequel>.freeze, [">= 3.38", "< 6.0"])
  s.add_runtime_dependency(%q<delayed_job>.freeze, ["~> 4.1.0"])
  s.add_runtime_dependency(%q<tzinfo>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.6.0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
end
