require "rubocop/rake_task"

RuboCop::RakeTask.new(:lint)

namespace :lint do
  task :changed do
    sh("git status --porcelain | cut -c4- | grep '.rb' | xargs rubocop")
  end
end
