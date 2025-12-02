# -*- encoding: utf-8 -*-
# stub: cf-uaa-lib 4.0.9 ruby lib

Gem::Specification.new do |s|
  s.name = "cf-uaa-lib".freeze
  s.version = "4.0.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Dave Syer".freeze, "Dale Olds".freeze, "Joel D'sa".freeze, "Vidya Valmikinathan".freeze, "Luke Taylor".freeze]
  s.date = "2025-02-19"
  s.description = "Client library for interacting with the CloudFoundry User Account and Authorization (UAA) server.  The UAA is an OAuth2 Authorization Server so it can be used by webapps and command line apps to obtain access tokens to act on behalf of users.  The tokens can then be used to access protected resources in a Resource Server.  This library is for use by UAA client applications or resource servers.".freeze
  s.email = ["dsyer@vmware.com".freeze, "olds@vmware.com".freeze, "jdsa@vmware.com".freeze, "vidya@vmware.com".freeze, "ltaylor@vmware.com".freeze]
  s.homepage = "https://github.com/cloudfoundry/cf-uaa-lib".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Client library for CloudFoundry UAA".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<json>.freeze, ["~> 2.7"])
  s.add_runtime_dependency(%q<mutex_m>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<base64>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<httpclient>.freeze, ["~> 2.8", ">= 2.8.2.4"])
  s.add_runtime_dependency(%q<addressable>.freeze, ["~> 2.8", ">= 2.8.0"])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 2.2"])
  s.add_development_dependency(%q<rake>.freeze, [">= 10.3.2", "~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 2.14.1", "~> 3.9"])
  s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.22.0"])
  s.add_development_dependency(%q<simplecov-rcov>.freeze, ["~> 0.3.0"])
  s.add_development_dependency(%q<ci_reporter>.freeze, [">= 1.9.2", "~> 2.0"])
  s.add_development_dependency(%q<ci_reporter_rspec>.freeze, ["~> 1.0"])
end
