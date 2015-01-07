begin

  require "rubocop/rake_task"

  desc "Run RuboCop"
  RuboCop::RakeTask.new(:rubocop)

rescue LoadError

  dummy_task_message = "rubocop/rake_task could not be loaded"
  desc "Dummy RuboCop task: #{dummy_task_message}"
  task :rubocop do
    puts "NoOp: #{dummy_task_message}"
  end

end
