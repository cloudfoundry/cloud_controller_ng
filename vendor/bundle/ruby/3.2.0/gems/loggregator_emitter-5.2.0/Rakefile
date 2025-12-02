require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)
task :default => :spec

RSpec::Core::RakeTask.new(:performance) do |t|
  t.rspec_opts = "--tag performance"
end

RSpec::Core::RakeTask.new(:nonperformance) do |t|
  t.rspec_opts = "--tag ~performance"
end
