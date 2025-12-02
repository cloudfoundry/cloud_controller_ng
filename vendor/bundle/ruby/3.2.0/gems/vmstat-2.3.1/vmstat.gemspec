# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vmstat/version'

Gem::Specification.new do |gem|
  gem.name          = "vmstat"
  gem.version       = Vmstat::VERSION
  gem.authors       = ["Vincent Landgraf"]
  gem.email         = ["vilandgr@googlemail.com"]
  gem.description   = %q{
    A focused and fast library to gather memory, 
    cpu, network, load avg and disk information
  }
  gem.summary       = %q{A focused and fast library to gather system information}
  gem.homepage      = "http://threez.github.com/ruby-vmstat/"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.extensions    = ["ext/vmstat/extconf.rb"]

  gem.add_development_dependency('rake', '~> 11.3')
  gem.add_development_dependency('rspec', '~> 2.9')
  gem.add_development_dependency('rake-compiler')
  gem.add_development_dependency('guard-rspec')
  gem.add_development_dependency('timecop')
end
