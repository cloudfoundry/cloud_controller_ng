# Copyright (c) 2009-2012 VMware, Inc.
require "rspec"
require "rspec/core/rake_task"

environments = %w(test development production)

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = ["--format", "documentation", "--colour"]
end

desc "Run specs with code coverage"
task :coverage do
  require "simplecov"

  SimpleCov.coverage_dir(File.join("spec", "artifacts", "coverage"))
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/migrations/"
    RSpec::Core::Runner.disable_autorun!
    RSpec::Core::Runner.run(['.'])
  end
end

task "spec:rcov" => :coverage

namespace :db do
  # TODO: add migration support

  desc "Create a Sequel migration in ./db/migrate"
  task :create_migration do
    name = ENV["NAME"]
    abort("no NAME specified. use `rake db:create_migration NAME=add_users`") if !name

    migrations_dir = File.join("db", "migrations")
    version = ENV["VERSION"] || Time.now.utc.strftime("%Y%m%d%H%M%S")
    filename = "#{version}_#{name}.rb"
    FileUtils.mkdir_p(migrations_dir)

    open(File.join(migrations_dir, filename), "w") do |f|
      f.write <<-EOF
# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
  end
end
      EOF
    end
  end
end
