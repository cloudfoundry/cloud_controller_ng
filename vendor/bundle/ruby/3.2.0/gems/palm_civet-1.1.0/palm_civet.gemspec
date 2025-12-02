
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "palm_civet/version"

Gem::Specification.new do |spec|
  spec.name          = "palm_civet"
  spec.version       = PalmCivet::VERSION
  spec.authors       = ["Anand Gaitonde"]

  spec.summary       = %q{Human readable byte formatter.}
  spec.description   = %q{A ruby port of github.com/cloudfoundry/bytefmt.}
  spec.homepage      = "https://github.com/XenoPhex/palm_civet"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
