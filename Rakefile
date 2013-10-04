# Copyright (c) 2009-2012 VMware, Inc.
$:.unshift(File.expand_path("../lib", __FILE__))
$:.unshift(File.expand_path("../app", __FILE__))

require "yaml"
require "sequel"
require "steno"
require "cloud_controller"


ENV['CI_REPORTS'] = File.join("spec", "artifacts", "reports")

namespace :db do
  desc "Create a Sequel migration in ./db/migrate"
  task :create_migration do
    name = ENV["NAME"]
    type = ENV.fetch("TYPE", "sequel")

    abort("no NAME specified. use `rake db:create_migration NAME=add_users`") if !name

    migrations_dir = File.join("db", "migrations")

    version = ENV["VERSION"] || Time.now.utc.strftime("%Y%m%d%H%M%S")
    filename = "#{version}_#{name}.rb"
    FileUtils.mkdir_p(migrations_dir)

    open(File.join(migrations_dir, filename), "w") do |f|
      f.write migration_stub
    end
  end

  def migration_stub
<<-Ruby
Sequel.migration do
  change do
  end
end
Ruby
  end

  def db
    @db ||= begin
      run_initializers
      connect_to_database
    end
  end

  desc "Perform Sequel migration to database"
  task :migrate do
    VCAP::CloudController::DB.apply_migrations(db)
  end

  desc "Rollback a single migration to the database"
  task :rollback do
    number_to_rollback = 1
    recent_migrations = db[:schema_migrations].order(Sequel.desc(:filename)).limit(number_to_rollback + 1).all
    recent_migrations = recent_migrations.collect {|hash| hash[:filename].split("_", 2).first.to_i }
    VCAP::CloudController::DB.apply_migrations(db, :current => recent_migrations.first, :target => recent_migrations.last)
  end

  namespace :migrate do
    desc "Rollback the most recent migration and remigrate to current"
    task :redo => [:rollback, :migrate]
  end
end

namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear do
    setup_environment
    Delayed::Job.delete_all
  end

  desc "Start a delayed_job worker."
  task :work => :environment_options do
    setup_environment
    Delayed::Worker.destroy_failed_jobs = false
    Delayed::Worker.new(@worker_options).start
  end

  task :environment_options do
    @worker_options = {
      :min_priority => ENV['MIN_PRIORITY'],
      :max_priority => ENV['MAX_PRIORITY'],
      :queues => (ENV['QUEUES'] || ENV['QUEUE'] || '').split(','),
      :quiet => false
    }
  end
end

def connect_to_database
  VCAP::CloudController::Config.db_encryption_key = config[:db_encryption_key]

  Steno.init(Steno::Config.new(:sinks => [Steno::Sink::IO.new(STDOUT)]))
  db_logger = Steno.logger("cc.db.migrations")

  VCAP::CloudController::DB.connect(db_logger, config[:db])
end

def setup_environment
  run_initializers
  connect_to_database
  VCAP::CloudController::DB.load_models
  VCAP::CloudController::Config.configure(config)
end

def run_initializers
  VCAP::CloudController::Config.run_initializers(config)
end

def config
  @config ||= begin
    config_file = ENV["CLOUD_CONTROLLER_NG_CONFIG"] || File.expand_path("../config/cloud_controller.yml", __FILE__)
    config = VCAP::CloudController::Config.from_file(config_file)
    config
  end
end
