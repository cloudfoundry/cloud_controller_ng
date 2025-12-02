lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fog/google/version"

Gem::Specification.new do |spec|
  spec.name          = "fog-google"
  spec.version       = Fog::Google::VERSION
  spec.authors       = ["Nat Welch", "Artem Yakimenko"]
  spec.email         = ["nat@natwelch.com", "temikus@google.com"]
  spec.summary       = "Module for the 'fog' gem to support Google."
  spec.description   = "This library can be used as a module for `fog` or as standalone provider to use the Google Cloud in applications."
  spec.homepage      = "https://github.com/fog/fog-google"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.start_with?("test/") }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # As of 0.1.1
  spec.required_ruby_version = ">= 2.0"

  spec.add_dependency "fog-core", "~> 2.5"
  spec.add_dependency "fog-json", "~> 1.2"
  spec.add_dependency "fog-xml", "~> 0.1.0"

  spec.add_dependency "google-apis-storage_v1", [">= 0.19", "< 1"]
  spec.add_dependency "google-apis-iamcredentials_v1", "~> 0.15"
  spec.add_dependency "google-apis-compute_v1", "~> 0.53"
  spec.add_dependency "google-apis-monitoring_v3", "~> 0.37"
  spec.add_dependency "google-apis-dns_v1", "~> 0.28"
  spec.add_dependency "google-apis-pubsub_v1", "~> 0.30"
  spec.add_dependency "google-apis-sqladmin_v1beta4", "~> 0.38"

  spec.add_dependency "google-cloud-env", ">= 1.2", "< 3.0"

  spec.add_dependency "addressable", ">= 2.7.0"

  # Debugger
  # Locked because pry-byebug is broken with 13+
  # see: https://github.com/deivid-rodriguez/pry-byebug/issues/343
  spec.add_development_dependency "pry", "= 0.15.2"

  # Testing gems
  spec.add_development_dependency "retriable"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "shindo"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"
end
