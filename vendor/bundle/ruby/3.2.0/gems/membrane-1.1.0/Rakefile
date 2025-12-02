#!/usr/bin/env rake
require "ci/reporter/rake/rspec"
require "rspec/core/rake_task"

desc "Run all specs"
RSpec::Core::RakeTask.new("spec") do |t|
  t.rspec_opts = %w[--color --format documentation]
end

desc "Run all specs and provide output for ci"
RSpec::Core::RakeTask.new("spec:ci" => "ci:setup:rspec") do |t|
  t.rspec_opts = %w[--no-color --format documentation]
end

task :default => [:spec]
