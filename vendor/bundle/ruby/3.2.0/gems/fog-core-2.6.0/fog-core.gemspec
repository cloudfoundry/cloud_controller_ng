# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fog/core/version"

Gem::Specification.new do |spec|
  spec.name          = "fog-core"
  spec.version       = Fog::Core::VERSION
  spec.authors       = ["Evan Light", "Wesley Beary"]
  spec.email         = ["evan@tripledogdare.net", "geemus@gmail.com"]
  spec.summary       = "Shared classes and tests for fog providers and services."
  spec.description   = "Shared classes and tests for fog providers and services."
  spec.homepage      = "https://github.com/fog/fog-core"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR).reject {|f| f.start_with? ('spec/') }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.0"

  spec.add_dependency("builder")
  spec.add_dependency("excon", "~> 1.0")
  spec.add_dependency("formatador", ">= 0.2", "< 2.0")
  spec.add_dependency("mime-types")

  # https://github.com/fog/fog-core/issues/206
  # spec.add_dependency("xmlrpc") if RUBY_VERSION.to_s >= "2.4"

  spec.add_development_dependency("minitest")
  spec.add_development_dependency("minitest-stub-const")
  spec.add_development_dependency("pry")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("rubocop")
  spec.add_development_dependency("rubocop-minitest")
  spec.add_development_dependency("rubocop-rake")
  spec.add_development_dependency("thor")
  spec.add_development_dependency("tins")
  spec.add_development_dependency("yard")

  spec.metadata["changelog_uri"] = spec.homepage + "/blob/master/changelog.md"
  spec.metadata["rubygems_mfa_required"] = "true"
end
