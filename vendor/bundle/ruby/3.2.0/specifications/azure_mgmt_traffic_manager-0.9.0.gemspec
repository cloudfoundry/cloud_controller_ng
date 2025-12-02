# -*- encoding: utf-8 -*-
# stub: azure_mgmt_traffic_manager 0.9.0 ruby lib

Gem::Specification.new do |s|
  s.name = "azure_mgmt_traffic_manager".freeze
  s.version = "0.9.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Microsoft Corporation".freeze]
  s.date = "2017-02-07"
  s.description = "Microsoft Azure Traffic Management Client Library for Ruby".freeze
  s.email = "azrubyteam@microsoft.com".freeze
  s.homepage = "https://aka.ms/azure-sdk-for-ruby".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "3.4.19".freeze
  s.summary = "Official Ruby client library to consume Microsoft Azure Traffic Management services.".freeze

  s.installed_by_version = "3.4.19" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, ["~> 1.9"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 10"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3"])
  s.add_development_dependency(%q<dotenv>.freeze, ["~> 2"])
  s.add_runtime_dependency(%q<ms_rest_azure>.freeze, ["~> 0.7.0"])
end
