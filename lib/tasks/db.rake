namespace :db do
  desc 'Create a Sequel migration in ./db/migrate'
  task :create_migration do
    name = ENV['NAME']
    abort('no NAME specified. use `rake db:create_migration NAME=add_users`') if !name

    migrations_dir = File.join('db', 'migrations')

    version = ENV['VERSION'] || Time.now.utc.strftime('%Y%m%d%H%M%S')
    filename = "#{version}_#{name}.rb"
    FileUtils.mkdir_p(migrations_dir)

    open(File.join(migrations_dir, filename), 'w') do |f|
      f.write <<~Ruby
        Sequel.migration do
          change do
          end
        end
      Ruby
      puts'*' * 134
      puts''
      puts "The migration is in #{File.join(migrations_dir, filename)}"
      puts ''
      puts 'Before writing a migration review our style guide: https://github.com/cloudfoundry/cloud_controller_ng/wiki/CAPI-Migration-Style-Guide'
      puts''
      puts'*' * 134
    end
  end

  def for_each_database
    if ENV['DB'] || ENV['DB_CONNECTION_STRING']
      RakeConfig.config.set(:db, RakeConfig.get(:db).merge({ database: DbConfig.new.connection_string }))
      yield
    else
      %w(postgres mysql).each do |db_type|
        RakeConfig.config.set(:db, RakeConfig.get(:db).merge({ database: DbConfig.new(db_type: db_type).connection_string }))
        puts "Using #{db_type}"
        yield

        DbConfig.reset_environment
      end
    end
  end

  def migrate
    Steno.init(Steno::Config.new(sinks: [Steno::Sink::IO.new(STDOUT)]))
    db_logger = Steno.logger('cc.db.migrations')
    DBMigrator.from_config(RakeConfig.config, db_logger).apply_migrations
  end

  desc 'Perform Sequel migration to database'
  task :migrate do
    migrate
  end

  def rollback(number_to_rollback)
    Steno.init(Steno::Config.new(sinks: [Steno::Sink::IO.new(STDOUT)]))
    db_logger = Steno.logger('cc.db.migrations')
    DBMigrator.from_config(RakeConfig.config, db_logger).rollback(number_to_rollback)
  end

  def parse_db_connection_string
    host = port = passenv = ''
    case ENV['DB']
    when 'postgres'
      user = '-U postgres'
      pass = ''
      if ENV['DB_CONNECTION_STRING']
        uri = URI.parse(ENV['DB_CONNECTION_STRING'])
        host = "-h #{uri.host}"
        port = "-p #{uri.port}" if uri.port
        if uri.user
          user = "-U #{uri.user}"
        end
        passenv = "PGPASSWORD=#{uri.password}" if uri.password
      end
    when 'mysql'
      user = '-u root'
      pass = '--password=password'
      if ENV['DB_CONNECTION_STRING']
        uri = URI.parse(ENV['DB_CONNECTION_STRING'])
        host = "-h #{uri.host}"
        port = "-P #{uri.port}" if uri.port
        if uri.user
          user = "-u #{uri.user}"
        end
        if uri.password
          pass = "--password=#{uri.password}"
        end
      end
    end
    [host, port, user, pass, passenv]
  end

  desc 'Rollback migrations to the database (one migration by default)'
  task :rollback, [:number_to_rollback] do |_, args|
    number_to_rollback = (args[:number_to_rollback] || 1).to_i
    rollback(number_to_rollback)
  end

  namespace :migrate do
    desc 'Rollback the most recent migration and remigrate to current'
    task redo: [:rollback, :migrate]
  end

  namespace :dev do
    desc 'Migrate the database set in spec/support/bootstrap/db_config'
    task :migrate do
      require_relative '../../spec/support/bootstrap/db_config'
      for_each_database { migrate }
    end

    desc 'Rollback the database migration set in spec/support/bootstrap/db_config'
    task :rollback, [:number_to_rollback] do |_, args|
      require_relative '../../spec/support/bootstrap/db_config'
      number_to_rollback = (args[:number_to_rollback] || 1).to_i
      for_each_database { rollback(number_to_rollback) }
    end
  end

  task :pick do
    unless ENV['DB_CONNECTION_STRING']
      ENV['DB'] ||= %w[mysql postgres].sample
      puts "Using #{ENV['DB']}"
    end
  end

  desc 'Create the database set in spec/support/bootstrap/db_config'
  task :create do
    require_relative '../../spec/support/bootstrap/db_config'
    db_config = DbConfig.new
    host, port, user, pass, passenv = parse_db_connection_string

    case ENV['DB']
    when 'postgres'
      sh "#{passenv} psql -q #{host} #{port} #{user} -c 'create database #{db_config.name};'"
      extensions = 'CREATE EXTENSION IF NOT EXISTS citext; CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; CREATE EXTENSION IF NOT EXISTS pgcrypto;'
      sh "#{passenv} psql -q #{host} #{port} #{user} -d #{db_config.name} -c '#{extensions}'"
    when 'mysql'
      if ENV['TRAVIS'] == 'true'
        sh "mysql -e 'create database #{db_config.name};' -u root"
      else
        sh "mysql #{host} #{port} #{user} #{pass} -e 'create database #{db_config.name};'"
      end
    else
      puts 'rake db:create requires DB to be set to create a database'
    end
  end

  desc 'Drop the database set in spec/support/bootstrap/db_config'
  task :drop do
    require_relative '../../spec/support/bootstrap/db_config'
    db_config = DbConfig.new
    host, port, user, pass, passenv = parse_db_connection_string

    case ENV['DB']
    when 'postgres'
      sh "#{passenv} psql -q #{host} #{port} #{user} -c 'drop database if exists #{db_config.name};'"
    when 'mysql'
      if ENV['TRAVIS'] == 'true'
        sh "mysql -e 'drop database if exists #{db_config.name};' -u root"
      else
        sh "mysql #{host} #{port} #{user} #{pass} -e 'drop database if exists #{db_config.name};'"
      end
    else
      puts 'rake db:drop requires DB to be set to create a database'
    end
  end

  task recreate: %w[drop create]

  namespace :parallel do
    task recreate: %w[parallel:drop parallel:create]
  end

  desc 'Seed the database'
  task :seed do
    require 'cloud_controller/seeds'
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment do
      VCAP::CloudController::Seeds.write_seed_data(RakeConfig.config)
    end
  end

  desc 'Ensure migrations in DB match local migration files'
  task :ensure_migrations_are_current do
    Steno.init(Steno::Config.new(sinks: [Steno::Sink::IO.new(STDOUT)]))
    db_logger = Steno.logger('cc.db.migrations')
    VCAP::CloudController::Encryptor.db_encryption_key = RakeConfig.config.get(:db_encryption_key)
    db = VCAP::CloudController::DB.connect(RakeConfig.config.get(:db), db_logger)

    latest_migration_in_db = db[:schema_migrations].order(Sequel.desc(:filename)).first[:filename]
    latest_migration_in_dir = File.basename(Dir['db/migrations/*'].sort.last)

    unless latest_migration_in_db == latest_migration_in_dir
      puts "Expected latest migration #{latest_migration_in_db} to equal #{latest_migration_in_dir}"
      exit 1
    end

    puts 'Successfully applied latest migrations to CF deployment'
  end
end
