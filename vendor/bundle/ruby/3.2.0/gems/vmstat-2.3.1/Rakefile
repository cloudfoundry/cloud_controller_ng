#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'rake/extensiontask'
require 'rspec/core/rake_task'

Rake::ExtensionTask.new(:vmstat) do |ext|
	ext.lib_dir = 'lib/vmstat'
end

desc "Run specs"
RSpec::Core::RakeTask.new(:spec => :compile)

desc "Open an irb session preloaded with smartstat"
task :console do
  sh "irb -rubygems -I ./lib -r vmstat"
end

desc 'Default: run specs.'
task :default => :spec