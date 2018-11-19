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
      if changelist.empty?
        abort 'No files have changed; consider running rake rubocop:local instead'
      end
      cli = RuboCop::CLI.new
      exit_code = cli.run(changelist.uniq.grep(/.*\.rb$/).unshift('--auto-correct'))
      exit(exit_code) if exit_code != 0
    end

    desc 'Auto-correct files changed from origin'
    task :local do
      require 'rubocop'
      current_branch = `git rev-parse --abbrev-ref HEAD`.chomp
      remote = `git remote -v | awk 'NR == 1 {print $1}'`.chomp
      remote = 'origin' if !remote || remote.empty?
      # git branches shouldn't have shell-hostile characters in them so don't quote
      changelist = `git diff --name-only #{current_branch} #{remote}/#{current_branch}`.chomp.split("\n")
      changelist -= `git diff --cached --name-only --diff-filter=D`.chomp.split("\n")
      if changelist.empty?
        abort 'No local files; consider running rake rubocop:changed instead'
      end
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
