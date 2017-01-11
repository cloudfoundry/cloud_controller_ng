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

task default: ['spec:all', 'rubocop:changed']

task rubocop_autocorrect: ['rubocop:changed']
