# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fog/aliyun/version'

Gem::Specification.new do |spec|
  spec.name = 'fog-aliyun'
  spec.version = Fog::Aliyun::VERSION
  spec.authors = ['Qinsi Deng, Jianxun Li, Jane Han, Guimin He']
  spec.email = ['dengqinsi@sina.com', 'guimin.hgm@alibaba-inc.com']

  spec.summary = 'Fog provider for Alibaba Cloud Web Services.'
  spec.description = 'As a FOG provider, fog-aliyun support aliyun OSS/ECS. It will support more aliyun services later.'
  spec.homepage = 'https://github.com/fog/fog-aliyun'
  spec.license = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'mime-types', '~> 3.4'
  spec.add_development_dependency 'pry-nav'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'memory_profiler'
  spec.add_development_dependency 'aliyun-sdk', '~> 0.8.0'

  spec.add_dependency 'addressable', '~> 2.8.0'
  spec.add_dependency 'aliyun-sdk', '~> 0.8.0'
  spec.add_dependency 'fog-core'
  spec.add_dependency 'fog-json'
  spec.add_dependency 'ipaddress', '~> 0.8'
  spec.add_dependency 'xml-simple', '~> 1.1'
end
