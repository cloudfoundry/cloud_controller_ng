if ENV['DB'] == 'postgresql'
  warn('Resetting env var DB from postgresql to postgres...')
  ENV['DB'] = 'postgres'
end

require File.expand_path('../config/boot', __FILE__)

require 'yaml'
require 'sequel'
require 'steno'
require 'cloud_controller'
require_relative 'lib/tasks/rake_config'
require 'colorize'
require 'English'

Rails.application.load_tasks

begin
  require 'parallel_tests/tasks'
rescue LoadError
  # this isn't needed in a production environment so the gem will not exist
end

default_tasks = ['spec:all', :check_doc_links]

ENV['RUBOCOP_FIRST'] ? default_tasks.unshift(:rubocop_autocorrect) : default_tasks.push(:rubocop_autocorrect)

task default: default_tasks

task :rubocop_autocorrect do
  require 'rubocop'
  cli = RuboCop::CLI.new
  exit_code = cli.run(%w(--auto-correct))
  exit(exit_code) if exit_code != 0
end

task :check_doc_links do
  puts 'Checkling links in all docs...'.green
  Bundler.with_clean_env do
    Dir.chdir('docs/v3') do
      status = system('npm install && gulp checkdocs')
      exit $CHILD_STATUS.exitstatus if !status
      puts 'check_doc_links OK'.green
    end
  end
end

Rake::Task['doc:app'].clear
