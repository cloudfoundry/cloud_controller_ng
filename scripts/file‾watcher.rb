#!/usr/bin/env ruby

# file-watcher.rb - Wait for files to change, and run associated tests
#
# usage: bundle exec scripts/file-watcher.rb

require 'listen'

spork_thread = Thread.new do
  system('bundle exec spork')
end

def gather_spec_files(files)
  files2 = files.reject { |x| x['#'] || x['~'] }.map { |x| x.sub("#{Dir.pwd}/", '') }
  spec_files, other = files2.partition { |x| %r{^spec/} =~ x }
  app_files, lib_files = other.partition { |x| %r{^app/} =~ x }
  app_spec_files = app_files.map { |x| "spec/unit/#{x[4..-4]}_spec.rb" }.select { |x| File.exist?(x) }
  lib_spec_files = lib_files.map { |x| "spec/unit/#{x[0..-4]}_spec.rb" }.select { |x| File.exist?(x) }
  spec_files + app_spec_files + lib_spec_files
end

listener = Listen.to('app', 'lib', 'spec', only: /.*\.rb$/) do |modified, added, removed|
  files = (modified + added + removed)
  spec_files = gather_spec_files(files)
  system("bundle exec rspec --drb #{spec_files.join(' ')}") if !spec_files.empty?
end
listener.start # not blocking
sleep
spork_thread.join
