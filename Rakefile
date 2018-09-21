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
  require 'English'
  require 'rainbow'

  puts Rainbow('Checking links in all docs...').green
  Bundler.with_clean_env do
    Dir.chdir('docs/v3') do
      status = system('npm install && npm run checkdocs')
      exit $CHILD_STATUS.exitstatus if !status
      puts Rainbow('check_doc_links OK').green
    end
  end
end
