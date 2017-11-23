require File.expand_path('../config/boot', __FILE__)

require 'yaml'
require 'sequel'
require 'steno'
require 'cloud_controller'
require_relative 'lib/tasks/rake_config'

Rails.application.load_tasks

begin
  require 'parallel_tests/tasks'
rescue LoadError
  # this isn't needed in a production environment so the gem will not exist
end

default_tasks = ['spec:all', :rubocop_autocorrect]
task default: ENV['RUBOCOP_FIRST'] ? default_tasks.reverse : default_tasks

task :rubocop_autocorrect do
  require 'rubocop'
  cli = RuboCop::CLI.new
  exit_code = cli.run(%w(--auto-correct))
  exit(exit_code) if exit_code != 0
end

Rake::Task['doc:app'].clear
