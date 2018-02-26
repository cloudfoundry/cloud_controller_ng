lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "copilot/version"

Gem::Specification.new do |spec|
  spec.name          = 'cf-copilot'
  spec.version       = Cloudfoundry::Copilot::VERSION
  spec.authors       = ['Cloud Foundry Routing Team']
  spec.email         = ['cf-routing@pivotal.io']

  spec.summary       = %q{Ruby client for copilot (a CF istio data transformer).}

  spec.files         = Dir.glob('{bin,lib}/**/*')
  spec.files         += %w[LICENSE NOTICE README.md]
  spec.license       = 'Apache-2.0'
  spec.require_paths = ['lib', 'lib/copilot/protos']

  spec.add_dependency 'grpc', '~> 1.0'

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
