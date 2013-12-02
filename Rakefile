$:.unshift(File.expand_path("../lib", __FILE__))
$:.unshift(File.expand_path("../app", __FILE__))

require "yaml"
require "sequel"
require "steno"
require "cloud_controller"

namespace :db do
  desc "Create a Sequel migration in ./db/migrate"
  task :create_migration do
    name = ENV["NAME"]
    abort("no NAME specified. use `rake db:create_migration NAME=add_users`") if !name

    migrations_dir = File.join("db", "migrations")

    version = ENV["VERSION"] || Time.now.utc.strftime("%Y%m%d%H%M%S")
    filename = "#{version}_#{name}.rb"
    FileUtils.mkdir_p(migrations_dir)

    open(File.join(migrations_dir, filename), "w") do |f|
      f.write <<-Ruby
Sequel.migration do
  change do
  end
end
      Ruby
    end
  end

  desc "Perform Sequel migration to database"
  task :migrate do
    Steno.init(Steno::Config.new(sinks: [Steno::Sink::IO.new(STDOUT)]))
    db_logger = Steno.logger("cc.db.migrations")
    DBMigrator.from_config(config, db_logger).apply_migrations
  end

  desc "Rollback a single migration to the database"
  task :rollback do
    Steno.init(Steno::Config.new(sinks: [Steno::Sink::IO.new(STDOUT)]))
    db_logger = Steno.logger("cc.db.migrations")
    DBMigrator.from_config(config, db_logger).rollback(number_to_rollback=1)
  end

  namespace :migrate do
    desc "Rollback the most recent migration and remigrate to current"
    task :redo => [:rollback, :migrate]
  end
end

namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear do
    BackgroundJobEnvironment.new(config).setup_environment
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work do
    queue_options = {
      min_priority: ENV['MIN_PRIORITY'],
      max_priority: ENV['MAX_PRIORITY'],
      queues: (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
      quiet: false
    }
    BackgroundJobEnvironment.new(config).setup_environment
    Delayed::Worker.destroy_failed_jobs = false
    Delayed::Worker.new(queue_options).start
  end
end

def config
  @config ||= begin
    config_file = ENV["CLOUD_CONTROLLER_NG_CONFIG"] || File.expand_path("../config/cloud_controller.yml", __FILE__)
    config = VCAP::CloudController::Config.from_file(config_file)
    config
  end
end
