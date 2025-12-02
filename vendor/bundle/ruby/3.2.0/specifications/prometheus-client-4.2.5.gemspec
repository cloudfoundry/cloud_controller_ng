# -*- encoding: utf-8 -*-
# stub: prometheus-client 4.2.5 ruby lib

Gem::Specification.new do |s|
  s.name = "prometheus-client".freeze
  s.version = "4.2.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ben Kochie".freeze, "Chris Sinjakli".freeze, "Daniel Magliola".freeze]
  s.date = "2025-07-05"
  s.email = ["superq@gmail.com".freeze, "chris@sinjakli.co.uk".freeze, "dmagliola@crystalgears.com".freeze]
  s.homepage = "https://github.com/prometheus/client_ruby".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "A suite of instrumentation metric primitivesthat can be exposed through a web services interface.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<base64>.freeze, [">= 0"])
  s.add_development_dependency(%q<benchmark>.freeze, [">= 0"])
  s.add_development_dependency(%q<benchmark-ips>.freeze, [">= 0"])
  s.add_development_dependency(%q<concurrent-ruby>.freeze, [">= 0"])
  s.add_development_dependency(%q<timecop>.freeze, [">= 0"])
end
