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

  desc "Rollback migrations to the database (one migration by default)"
  task :rollback, [:number_to_rollback] do |_, args|
    number_to_rollback = (args[:number_to_rollback] || 1).to_i
    Steno.init(Steno::Config.new(sinks: [Steno::Sink::IO.new(STDOUT)]))
    db_logger = Steno.logger("cc.db.migrations")
    DBMigrator.from_config(config, db_logger).rollback(number_to_rollback)
  end

  namespace :migrate do
    desc "Rollback the most recent migration and remigrate to current"
    task :redo => [:rollback, :migrate]
  end

  namespace :dev do
    task :migrate do
      require_relative "../../spec/support/bootstrap/db_config"

      config[:db][:database] = DbConfig.connection_string
      Rake::Task["db:migrate"].invoke
    end

    task :rollback, [:number_to_rollback] do |_, args|
      require_relative "../../spec/support/bootstrap/db_config"

      config[:db][:database] = DbConfig.connection_string
      Rake::Task["db:rollback"].invoke(args[:number_to_rollback])
    end
  end

  task :pick do
    unless ENV["DB_CONNECTION_STRING"] || ENV["DB_CONNECTION"]
      ENV["DB"] ||= %w[mysql postgres].sample
      puts "Using #{ENV["DB"]}"
    end
  end

  task :create do
    require_relative "../../spec/support/bootstrap/db_config"

    case ENV["DB"]
      when "postgres"
        sh "psql -U postgres -c 'create database #{DbConfig.name};'"
        sh "psql -U postgres -d #{DbConfig.name} -c 'CREATE EXTENSION IF NOT EXISTS citext'"
      when "mysql"
        if ENV["TRAVIS"] == "true"
          sh "mysql -e 'create database #{DbConfig.name};' -u root"
        else
          sh "mysql -e 'create database #{DbConfig.name};' -u root --password=password"
        end
      else
        puts "rake db:create requires DB to be set to create a database"
    end
  end

  task :drop do
    require_relative "../../spec/support/bootstrap/db_config"

    case ENV["DB"]
      when "postgres"
        sh "psql -U postgres -c 'drop database if exists #{DbConfig.name};'"
      when "mysql"
        if ENV["TRAVIS"] == "true"
          sh "mysql -e 'drop database if exists #{DbConfig.name};' -u root"
        else
          sh "mysql -e 'drop database if exists #{DbConfig.name};' -u root --password=password"
        end
      else
        puts "rake db:drop requires DB to be set to create a database"
    end
  end

  task recreate: %w[drop create]
end
