# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'digest/xxhash/version'

Gem::Specification.new do |spec|
  spec.name          = "digest-xxhash"
  spec.version       = Digest::XXHash::VERSION
  spec.authors       = ["konsolebox"]
  spec.email         = ["konsolebox@gmail.com"]
  spec.summary       = "A Digest framework based XXHash library for Ruby"
  spec.description   = <<-EOF
    This gem provides XXH32, XXH64, XXH3_64bits and XXH3_128bits
    functionalities for Ruby.  It inherits Digest::Class and complies
    with Digest::Instance's functional design.
  EOF
  spec.homepage      = "https://github.com/konsolebox/digest-xxhash-ruby"
  spec.license       = "MIT"

  spec.required_ruby_version = '>= 2.2'

  spec.files = %w[
    Gemfile
    LICENSE
    README.md
    Rakefile
    digest-xxhash.gemspec
    ext/digest/xxhash/debug-funcs.h
    ext/digest/xxhash/ext.c
    ext/digest/xxhash/extconf.rb
    ext/digest/xxhash/utils.h
    ext/digest/xxhash/xxhash.h
    lib/digest/xxhash/version.rb
    rakelib/alt-install-task.rake
    test/produce-vectors-with-ruby-xxhash.rb
    test/produce-vectors-with-xxhsum.rb
    test/test.rb
    test/test.vectors
    test/xxhsum.c.c0e86bc0.diff
  ]
  spec.test_files    = spec.files.grep(%r{^test/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rake-compiler", "~> 1.2", ">= 1.2.3"
  spec.add_development_dependency "minitest", "~> 5.8"

  spec.extensions = %w[ext/digest/xxhash/extconf.rb]
end
