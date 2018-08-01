begin

  require 'rubocop/rake_task'

  desc 'Run RuboCop'
  RuboCop::RakeTask.new(:rubocop)

  namespace :rubocop do
    desc 'Auto-correct changed files'
    task :changed do
      require 'rubocop'
      changelist = `git diff --name-only`.chomp.split("\n")
      changelist += `git diff --cached --name-only`.chomp.split("\n")
      changelist -= `git diff --cached --name-only --diff-filter=D`.chomp.split("\n")
      cli = RuboCop::CLI.new
      exit_code = cli.run(changelist.uniq.grep(/.*\.rb$/).unshift('--auto-correct'))
      exit(exit_code) if exit_code != 0
    end

    desc 'Auto-correct files changed from origin'
    task :local do
      require 'rubocop'
      changelist = `git diff --name-only origin`.chomp.split("\n")
      changelist -= `git diff --cached --name-only --diff-filter=D`.chomp.split("\n")
      cli = RuboCop::CLI.new
      exit_code = cli.run(changelist.uniq.grep(/.*\.rb$/).unshift('--auto-correct'))
      exit(exit_code) if exit_code != 0
    end
  end
rescue LoadError

  dummy_task_message = 'rubocop/rake_task could not be loaded'
  desc "Dummy RuboCop task: #{dummy_task_message}"
  task :rubocop do
    puts "NoOp: #{dummy_task_message}"
  end

end
