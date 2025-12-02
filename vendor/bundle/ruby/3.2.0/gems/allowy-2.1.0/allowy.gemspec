# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "allowy/version"

Gem::Specification.new do |s|
  s.name        = "allowy"
  s.version     = Allowy::VERSION
  s.authors     = ["Dmytrii Nagirniak"]
  s.email       = ["dnagir@gmail.com"]
  s.homepage    = "https://github.com/dnagir/allowy"
  s.summary     = %q{Authorization with simplicity and explicitness in mind}
  s.description = %q{Allowy provides CanCan-like way of checking permission but doesn't enforce a tight DSL giving you more control}
  s.licenses    = ["MIT"]

  s.rubyforge_project = "allowy"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]


  s.add_runtime_dependency "i18n"
  s.add_runtime_dependency "activesupport", ">= 3.2"

  s.add_development_dependency "rspec"
  s.add_development_dependency "its"
  s.add_development_dependency "pry"
  s.add_development_dependency "guard"
  s.add_development_dependency "guard-rspec"
end
