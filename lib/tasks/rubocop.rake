begin

  require 'rubocop/rake_task'

  desc 'Run RuboCop'
  RuboCop::RakeTask.new(:rubocop)

  def run_rubocop(changelist=nil)
    if changelist
      paths = changelist.uniq.grep(/.*\.rb$/)
      if paths.size == 0
        puts "0 uncommitted files found"
        exit(0)
      end
    else
      paths = []
    end
    require 'rubocop'
    cli = RuboCop::CLI.new
    exit_code = cli.run(paths.unshift('--auto-correct'))
    exit(exit_code) if exit_code > 0
  end

  namespace :rubocop do
    desc 'Auto-correct changed files'
    task :changed do
      changelist = `git diff --name-only`.chomp.split("\n")
      changelist += `git diff --cached --name-only`.chomp.split("\n")
      changelist -= `git diff --cached --name-only --diff-filter=D`.chomp.split("\n")
      run_rubocop(changelist)
    end

    desc 'Auto-correct files changed from origin'
    task :local do
      changelist = `git diff --name-only origin`.chomp.split("\n")
      changelist -= `git diff --cached --name-only --diff-filter=D origin`.chomp.split("\n")
      run_rubocop(changelist)
    end

    desc 'Auto-correct all files'
    task :all do
      run_rubocop(nil)
    end
    
    desc "Don't auto-correct all files"
    task :nocorrect do
      require 'rubocop'
      cli = RuboCop::CLI.new
      exit_code = cli.run()
      exit(exit_code) if exit_code > 0
    end
  end
rescue LoadError

  dummy_task_message = 'rubocop/rake_task could not be loaded'
  desc "Dummy RuboCop task: #{dummy_task_message}"
  task :rubocop do
    puts "NoOp: #{dummy_task_message}"
  end

end
