require File.expand_path('../config/boot', __FILE__)

require 'yaml'
require 'sequel'
require 'steno'
require 'cloud_controller'
require_relative 'lib/tasks/rake_config'

Rails.application.load_tasks

task default: ['spec:all', :rubocop_autocorrect]

task :rubocop_autocorrect do
  require 'rubocop'
  cli = RuboCop::CLI.new
  exit_code = cli.run(%w(--auto-correct))
  exit(exit_code) if exit_code != 0
end
