require 'httpclient'

namespace :db do
  desc 'Create a Sequel migration in ./db/migrate'
  task create_migration: :environment do
    RakeConfig.context = :migrate

    name = ENV.fetch('NAME', nil)
    abort('no NAME specified. use `rake db:create_migration NAME=add_users`') unless name

    migrations_dir = File.join('db', 'migrations')

    version = ENV['VERSION'] || Time.now.utc.strftime('%Y%m%d%H%M%S')
    filename = "#{version}_#{name}.rb"
    FileUtils.mkdir_p(migrations_dir)

    File.open(File.join(migrations_dir, filename), 'w') do |f|
      f.write <<~RUBY
        Sequel.migration do
          change do
          end
        end
      RUBY
      puts '*' * 134
      puts ''
      puts "The migration is in #{File.join(migrations_dir, filename)}"
      puts ''
      puts 'Before writing a migration review our style guide: https://github.com/cloudfoundry/cloud_controller_ng/wiki/CAPI-Migration-Style-Guide'
      puts ''
      puts '*' * 134
    end
  end

  desc 'Perform Sequel migration to database'
  task migrate: :environment do
    RakeConfig.context = :migrate

    migrate
  end

  desc 'Make up to 5 attempts to connect to the database. Succeed if one is successful, and fail otherwise.'
  task connect: :environment do
    RakeConfig.context = :migrate

    connect
  end

  desc 'Rollback migrations to the database (one migration by default)'
  task :rollback, [:number_to_rollback] => :environment do |_, args|
    RakeConfig.context = :migrate

    number_to_rollback = (args[:number_to_rollback] || 1).to_i
    rollback(number_to_rollback)
  end

  desc 'Randomly select between postgres and mysql'
  task pick: :environment do
    unless ENV['DB_CONNECTION_STRING']
      ENV['DB'] ||= %w[mysql postgres].sample
      puts "Using #{ENV.fetch('DB', nil)}"
    end
  end

  desc 'Create the database set in spec/support/bootstrap/db_config'
  task create: :environment do
    RakeConfig.context = :migrate

    require_relative '../../spec/support/bootstrap/db_config'
    db_config = DbConfig.new
    host, port, user, pass, passenv = parse_db_connection_string

    case ENV.fetch('DB', nil)
    when 'postgres'
      sh "#{passenv} psql -q #{host} #{port} #{user} -c 'create database #{db_config.name};'"
      extensions = 'CREATE EXTENSION IF NOT EXISTS citext; CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; CREATE EXTENSION IF NOT EXISTS pgcrypto;'
      sh "#{passenv} psql -q #{host} #{port} #{user} -d #{db_config.name} -c '#{extensions}'"
    when 'mysql'
      sh "mysql #{host} #{port} #{user} #{pass} -e 'create database #{db_config.name};'"
    else
      puts 'rake db:create requires DB to be set to create a database'
    end
  end

  desc 'Drop the database set in spec/support/bootstrap/db_config'
  task drop: :environment do
    RakeConfig.context = :migrate

    require_relative '../../spec/support/bootstrap/db_config'
    db_config = DbConfig.new
    host, port, user, pass, passenv = parse_db_connection_string

    case ENV.fetch('DB', nil)
    when 'postgres'
      sh "#{passenv} psql -q #{host} #{port} #{user} -c 'drop database if exists #{db_config.name};'"
    when 'mysql'
      sh "mysql #{host} #{port} #{user} #{pass} -e 'drop database if exists #{db_config.name};'"
    else
      puts 'rake db:drop requires DB to be set to create a database'
    end
  end

  desc 'Drop and create the database set in spec/support/bootstrap/db_config'
  task recreate: %w[drop create]

  desc 'Seed the database'
  task seed: :environment do
    RakeConfig.context = :api

    require 'cloud_controller/seeds'
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment do
      VCAP::CloudController::Seeds.write_seed_data(RakeConfig.config)
    end
  end

  desc 'Migrate and seed database'
  task setup_database: :environment do
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:seed'].invoke
  end

  desc 'Ensure migrations in DB match local migration files'
  task ensure_migrations_are_current: :environment do
    RakeConfig.context = :migrate

    logging_output
    db_logger = Steno.logger('cc.db.migrations')
    RakeConfig.config.load_db_encryption_key
    db = VCAP::CloudController::DB.connect(RakeConfig.config.get(:db), db_logger)

    latest_migration_in_db = db[:schema_migrations].order(Sequel.desc(:filename)).first[:filename]
    latest_migration_in_dir = File.basename(Dir['db/migrations/*.rb'].max)

    unless latest_migration_in_db == latest_migration_in_dir
      puts "Expected latest migration #{latest_migration_in_db} to equal #{latest_migration_in_dir}"
      exit 1
    end

    puts 'Successfully applied latest migrations to CF deployment'
  end

  desc 'Connect to the database set in spec/support/bootstrap/db_config'
  task connect: :environment do
    RakeConfig.context = :migrate

    require_relative '../../spec/support/bootstrap/db_config'
    db_config = DbConfig.new
    host, port, user, pass, passenv = parse_db_connection_string

    case ENV.fetch('DB', nil)
    when 'postgres'
      sh "#{passenv} psql -q #{host} #{port} #{user} -d #{db_config.name}"
    when 'mysql'
      sh "mysql #{host} #{port} #{user} #{pass}"
    else
      puts 'rake db:connect requires DB to be set to connect to a database'
    end
  end

  desc 'Terminate Istio sidecar for migration job (if one exists)'
  task terminate_istio_if_exists: :environment do
    puts 'Terminating Istio sidecar'

    terminate_istio_sidecar_if_exists
  end

  desc 'Validate Deployments are not missing encryption keys'
  task validate_encryption_keys: :environment do
    RakeConfig.context = :api

    require 'cloud_controller/validate_database_keys'
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment do
      VCAP::CloudController::ValidateDatabaseKeys.validate!(RakeConfig.config)
    rescue VCAP::CloudController::ValidateDatabaseKeys::ValidateDatabaseKeysError => e
      puts e.class
      puts e.message
      exit 1
    end
  end

  desc 'Backfill id_bigint column for a given table'
  task :bigint_backfill, %i[table batch_size iterations] => :environment do |_t, args|
    args.with_defaults(batch_size: 10_000, iterations: -1)
    raise ArgumentError.new("argument 'table' is required") if args.table.nil?

    RakeConfig.context = :migrate

    require 'database/bigint_migration'
    logging_output
    logger = Steno.logger('cc.db.bigint_backfill')
    RakeConfig.config.load_db_encryption_key
    db = VCAP::CloudController::DB.connect(RakeConfig.config.get(:db), logger)
    VCAP::BigintMigration.backfill(logger, db, args.table.to_sym, batch_size: args.batch_size.to_i, iterations: args.iterations.to_i)
  end

  namespace :dev do
    desc 'Migrate the database set in spec/support/bootstrap/db_config'
    task migrate: :environment do
      RakeConfig.context = :migrate

      require_relative '../../spec/support/bootstrap/db_config'

      for_each_database { migrate }
    end

    desc 'Rollback the database migration set in spec/support/bootstrap/db_config'
    task :rollback, [:number_to_rollback] => :environment do |_, args|
      RakeConfig.context = :migrate

      require_relative '../../spec/support/bootstrap/db_config'
      number_to_rollback = (args[:number_to_rollback] || 1).to_i
      for_each_database { rollback(number_to_rollback) }
    end

    desc 'Dump schema to file'
    task dump_schema: :environment do
      require_relative '../../spec/support/bootstrap/db_config'
      require_relative '../../spec/support/bootstrap/table_recreator'

      db = DbConfig.new.connection

      puts 'Recreating tables...'
      TableRecreator.new(db).recreate_tables(without_fake_tables: true)

      db.extension(:schema_dumper)
      puts 'Dumping schema...'
      schema = db.dump_schema_migration(indexes: true, foreign_keys: true)

      File.open('db/schema.rb', 'w') do |f|
        f.write("# rubocop:disable all\n")
        f.write(schema)
        f.write("# rubocop:enable all\n")
      end

      puts 'Wrote db/schema.rb'
    end
  end

  namespace :parallel do
    desc 'Drop and create / migrate the database set in spec/support/bootstrap/db_config in parallel'
    task recreate: %w[parallel:drop parallel:create]
    task migrate: %w[parallel:migrate]
  end

  def connect
    logging_output
    logger = Steno.logger('cc.db.connect')

    tries = 0
    begin
      VCAP::CloudController::DB.connect(RakeConfig.config.get(:db), logger)
    rescue StandardError => e
      tries += 1
      logger.info("[Attempt ##{tries}] Retrying because [#{e.class} - #{e.message}]: #{e.backtrace.first(5).join(' | ')}")
      sleep 1
      retry if tries < 60
      raise
    end

    logger.info('Successfully connected to database')
  end

  def migrate
    # The following block, which loads the test DB config is only needed for running migrations in parallel (only in tests)
    # It sets the `DB_CONNECTION_STRING` env variable from `POSTGRES|MYSQL_CONNECTION_PREFIX` + test_database number
    begin
      require_relative '../../spec/support/bootstrap/db_config'
      DbConfig.new
    rescue LoadError
      # In production the test DB config is not available nor needed, so we ignore this error.
    end

    logging_output
    db_logger = Steno.logger('cc.db.migrations')
    DBMigrator.from_config(RakeConfig.config, db_logger).apply_migrations
  end

  def rollback(number_to_rollback)
    # The following block, which loads the test DB config is only needed for running migrations in parallel (only in tests)
    # It sets the `DB_CONNECTION_STRING` env variable from `POSTGRES|MYSQL_CONNECTION_PREFIX` + test_database number
    begin
      require_relative '../../spec/support/bootstrap/db_config'
      DbConfig.new
    rescue LoadError
      # In production the test DB config is not available nor needed, so we ignore this error.
    end

    logging_output
    db_logger = Steno.logger('cc.db.migrations')
    DBMigrator.from_config(RakeConfig.config, db_logger).rollback(number_to_rollback)
  end

  def logging_output
    VCAP::CloudController::StenoConfigurer.new(RakeConfig.config.get(:logging)).configure do |steno_config_hash|
      if RakeConfig.config.get(:logging, :stdout_sink_enabled).nil? || RakeConfig.config.get(:logging, :stdout_sink_enabled)
        steno_config_hash[:sinks] << Steno::Sink::IO.new($stdout)
      end
    end
  end

  def parse_db_connection_string
    host = port = passenv = ''
    case ENV.fetch('DB', nil)
    when 'postgres'
      user = '-U postgres'
      pass = ''
      if ENV['DB_CONNECTION_STRING']
        uri = URI.parse(ENV['DB_CONNECTION_STRING'])
        host = "-h #{uri.host}"
        port = "-p #{uri.port}" if uri.port
        user = "-U #{uri.user}" if uri.user
        passenv = "PGPASSWORD=#{uri.password}" if uri.password
      end
    when 'mysql'
      user = '-u root'
      pass = '--password=password'
      if ENV['DB_CONNECTION_STRING']
        uri = URI.parse(ENV['DB_CONNECTION_STRING'])
        host = "-h #{uri.host}"
        port = "-P #{uri.port}" if uri.port
        user = "-u #{uri.user}" if uri.user
        pass = "--password=#{uri.password}" if uri.password
      end
    end
    [host, port, user, pass, passenv]
  end

  def for_each_database
    if ENV['DB'] || ENV['DB_CONNECTION_STRING']
      connection_string = DbConfig.new.connection_string
      RakeConfig.config.set(:db, RakeConfig.config.get(:db).merge(database: connection_string))

      yield
    else
      %w[postgres mysql].each do |db_type|
        connection_string = DbConfig.new(db_type:).connection_string
        RakeConfig.config.set(:db, RakeConfig.config.get(:db).merge(database: connection_string))
        yield

        DbConfig.reset_environment
      end
    end
  end

  def terminate_istio_sidecar_if_exists
    client = HTTPClient.new
    response = client.request(:post, 'http://localhost:15000/quitquitquit')

    unless response.code == 200
      puts "Failed to terminate Istio sidecar. Received response code: #{response.code}"
      return
    end

    puts 'Istio sidecar is now terminated'
  rescue StandardError => e
    puts "Request to Istio sidecar failed. This is expected if your kubernetes cluster does not use Istio. Error: #{e}"
  end
end
