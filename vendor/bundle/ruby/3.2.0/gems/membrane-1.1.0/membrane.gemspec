# -*- encoding: utf-8 -*-
require File.expand_path('../lib/membrane/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "membrane"
  gem.version       = Membrane::VERSION
  gem.summary       = "A DSL for validating data."
  gem.homepage      = "http://www.cloudfoundry.org"
  gem.authors       = ["mpage"]
  gem.email         = ["support@cloudfoundry.org"]
  gem.description   =<<-EOT
      Membrane provides an easy to use DSL for specifying validation
      logic declaratively.
      EOT

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency("ci_reporter")
  gem.add_development_dependency("rake")
  gem.add_development_dependency("rspec")
end
