# Copyright (c) 2009-2012 VMware, Inc.
require "rake"

environments = %w(test development production)

desc "Run specs"
task "spec" => ["bundler:install:test", "test:spec"]

desc "Run specs with code coverage"
task "spec:rcov" => ["bundler:install:test", "test:spec:rcov"]

namespace "bundler" do
  desc "install gems"
  task "install" do
    sh("bundle install")
  end

  environments = %w(test development production)
  environments.each do |env|
    desc "Install gems for #{env}"
    task "install:#{env}" do
      sh("bundle install --local --without #{(environments - [env]).join(" ")}")
    end
  end
end

namespace "test" do
  ["spec", "spec:rcov"].each do |task_name|
    task task_name do
      sh("cd spec && rake #{task_name}")
    end
  end
end

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
