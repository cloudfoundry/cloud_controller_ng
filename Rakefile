ENV['SINATRA_ACTIVESUPPORT_WARNING'] = 'false'

if ENV['DB'] == 'postgresql'
  warn('Resetting env var DB from postgresql to postgres...')
  ENV['DB'] = 'postgres'
end

require File.expand_path('config/boot', __dir__)

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

default_tasks = [:rubocop_autocorrect, 'spec:all', :check_doc_links]

task default: default_tasks

task rubocop_autocorrect: :environment do
  require 'rubocop'
  cli = RuboCop::CLI.new
  exit_code = cli.run(%w[--auto-correct --fail-level autocorrect])
  exit(exit_code) if exit_code != 0
end

desc 'Check docs for broken links'
task check_doc_links: :environment do
  require 'English'
  require 'rainbow'

  puts Rainbow('Checking links in all docs...').green
  Bundler.with_unbundled_env do
    Dir.chdir('docs/v3') do
      cmd = 'bundle install && npm install && npm run checkdocs'
      py2_path = '/usr/bin/python2.7'
      cmd = "npm config set python #{py2_path} #{cmd}" if File.exist?(py2_path)
      status = system(cmd)
      exit $CHILD_STATUS.exitstatus unless status
      puts Rainbow('check_doc_links OK').green
    end
  end
end
