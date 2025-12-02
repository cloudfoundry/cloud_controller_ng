# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'cloudfront-signer/version'

Gem::Specification.new do |s|
  s.name = 'cloudfront-signer'
  s.version = Aws::CF::VERSION
  s.authors = ['Anthony Bouch', 'Leonel Galan']
  s.email = ['tony@58bits.com', 'leonelgalan@gmail.com']
  s.homepage = 'http://github.com/leonelgalan/cloudfront-signer'
  s.summary = 'A gem to sign url and stream paths for Amazon CloudFront ' \
                  'private content.'
  s.description = 'A gem to sign url and stream paths for Amazon CloudFront ' \
                  'private content. Includes specific signing methods for ' \
                  "both url and streaming paths, including html 'safe' " \
                  'escaped versions of each.'
  s.license = 'MIT'

  s.rubyforge_project = 'cloudfront-signer'
  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'codeclimate-test-reporter', '>=1.0'
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n")
                                         .map { |f| File.basename f }
  s.require_paths = ['lib']
end
