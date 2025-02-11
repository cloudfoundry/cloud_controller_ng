require 'sequel'
require 'cloud_controller/db_migrator'
require 'cloud_controller/db_connection/options_factory'
require 'cloud_controller/db_connection/finalizer'
require 'sequel/extensions/query_length_logging'

module VCAP::CloudController
  class DB
    # Setup a Sequel connection pool
    #
    # @param [Logger]  Logger to pass to Sequel
    #
    # @option opts [String]  :database Database configuration values hash
    #
    # @option opts [Symbol]  :log_level Steno log level
    #
    # @option opts  [Integer] :max_connections The maximum number of
    # connections the connection pool will open (default 4)
    #
    # @option opts [Integer]  :pool_timeout The amount of seconds to wait to
    # acquire a connection before raising a PoolTimeoutError (default 5)
    #
    # @return [Sequel::Database]
    def self.connect(opts, logger)
      connection_options = VCAP::CloudController::DbConnection::OptionsFactory.build(opts)

      db = get_connection(opts, connection_options)

      if opts[:log_db_queries]
        db.logger = logger
        db.sql_log_level = opts[:log_level]
        db.extension :caller_logging
        db.caller_logging_ignore = /sequel_paginator|query_length_logging|sequel_pg|paginated_collection_renderer/
        db.caller_logging_formatter = lambda do |caller|
          "(#{caller.sub(%r{^.*/cloud_controller_ng/}, '')})"
        end

        db.extension(:query_length_logging)
        db.opts[:query_size_log_threshold] = opts[:query_size_log_threshold]
      end
      db.default_collate = 'utf8_bin' if db.database_type == :mysql
      add_connection_expiration_extension(db, opts)
      add_connection_validator_extension(db, opts)
      db.extension(:requires_unique_column_names_in_subquery)
      add_connection_metrics_extension(db)
      db
    end

    def self.get_database_scheme(opts)
      scheme = opts[:database][:adapter]
      scheme.starts_with?('mysql') ? 'mysql' : scheme
    end

    def self.get_connection(opts, connection_options)
      Sequel.connect(opts[:database].merge(connection_options))
    end

    def self.add_connection_validator_extension(db, opts)
      db.extension(:connection_validator)
      db.pool.connection_validation_timeout = opts[:connection_validation_timeout] if opts[:connection_validation_timeout]
    end

    def self.add_connection_expiration_extension(db, opts)
      return unless opts[:connection_expiration_timeout]

      db.extension(:connection_expiration)
      db.pool.connection_expiration_timeout = opts[:connection_expiration_timeout]
      db.pool.connection_expiration_random_delay = opts[:connection_expiration_random_delay] if opts[:connection_expiration_random_delay]
      # So that there are no existing connections without an expiration timestamp
      db.disconnect
    end

    def self.add_connection_metrics_extension(db)
      # only add the metrics for api processes. Otherwise e.g. rake db:migrate would also initialize metric updaters, which need additional config
      return if Object.const_defined?(:RakeConfig)

      db.extension(:connection_metrics)
      # so that we gather connection metrics from the beginning
      db.disconnect
    end

    def self.load_models(db_config, logger)
      db = connect(db_config, logger)
      DBMigrator.new(db).wait_for_migrations!

      require 'models'
      require 'delayed_job_sequel'
    end

    def self.load_models_without_migrations_check(db_config, logger)
      connect(db_config, logger)

      require 'models'
      require 'delayed_job_sequel'
    end
  end
end

Sequel.extension :inflector
Sequel::Model.raise_on_typecast_failure = false

Sequel::Model.plugin :association_dependencies
Sequel::Model.plugin :dirty
Sequel::Model.plugin :timestamps, update_on_create: true
Sequel::Model.plugin :validation_helpers

Sequel::Database.extension(:current_datetime_timestamp)
Sequel::Database.extension(:any_not_empty)

require 'cloud_controller/encryptor'
Sequel::Model.include VCAP::CloudController::Encryptor::FieldEncryptor

Sequel.split_symbols = true

class Sequel::Model
  private

  # monkey patch sequel to make it easier to map validation failures to custom
  # exceptions, e.g.
  #
  # rescue Sequel::ValidationFailed => e
  #   if e.errors.on(:some_attribute).include(:unique)

  def default_validation_helpers_options(type)
    val = super.deep_dup
    val[:message] = type

    val
  end
end

class Sequel::Dataset
  def post_load(all_records)
    return unless db.opts[:log_db_queries] && db.opts[:query_size_log_threshold]

    num_records = all_records.length
    return unless num_records >= db.opts[:query_size_log_threshold]

    db.loggers.each do |l|
      l.public_send(
        db.sql_log_level,
        "Loaded #{num_records} records for query #{sql.truncate 1000}"
      )
    end
  end

  def empty_from_sql
    ' FROM DUAL' if db.database_type == :mysql
  end
end

# Helper to create migrations.  This was added because
# I wanted to add an index to all the Timestamps so that
# we can enumerate by :created_at.
#
# decide on a better way of mixing this in to whatever
# context Sequel.migration is running in so that we can call
# the migration methods.
module VCAP
  module Migration
    PSQL_DEFAULT_STATEMENT_TIMEOUT = 30_000

    def self.timestamps(migration, table_key)
      created_at_idx = :"#{table_key}_created_at_index" if table_key
      updated_at_idx = :"#{table_key}_updated_at_index" if table_key
      migration.Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      migration.Timestamp :updated_at
      migration.index :created_at, name: created_at_idx
      migration.index :updated_at, name: updated_at_idx
    end

    def self.guid(migration, table_key)
      guid_idx = :"#{table_key}_guid_index" if table_key
      migration.String :guid, null: false
      migration.index :guid, unique: true, name: guid_idx
    end

    def self.common(migration, table_key=nil)
      migration.primary_key :id
      guid(migration, table_key)
      timestamps(migration, table_key)
    end

    def self.labels_common(migration, table_key, foreign_resource_table_key)
      migration.String :resource_guid, size: 255
      migration.String :key_prefix, size: 253
      migration.String :key_name, size: 63
      migration.String :value, size: 63

      migration.foreign_key [:resource_guid], foreign_resource_table_key, key: :guid, name: :"fk_#{table_key}_resource_guid"
      migration.index [:resource_guid], name: :"fk_#{table_key}_resource_guid_index"
      migration.index %i[key_prefix key_name value], name: :"#{table_key}_compound_index"
    end

    def self.annotations_common(migration, table_key, foreign_resource_table_key)
      migration.String :resource_guid, size: 255
      migration.String :key_prefix, size: 253
      migration.String :key, size: 1000
      migration.String :value, size: 5000

      migration.foreign_key [:resource_guid], foreign_resource_table_key, key: :guid, name: :"fk_#{table_key}_resource_guid"
      migration.index [:resource_guid], name: :"fk_#{table_key}_resource_guid_index"
    end

    def self.create_permission_table(migration, name, name_short, permission)
      name = name.to_s
      join_table = :"#{name.pluralize}_#{permission}"
      join_table_short = :"#{name_short}_#{permission}"
      id_attr = :"#{name}_id"
      idx_name = :"#{name_short}_#{permission}_idx"
      fk_name = :"#{join_table_short}_#{name_short}_fk"
      fk_user = :"#{join_table_short}_user_fk"
      table = name.pluralize.to_sym

      migration.create_table(join_table) do
        Integer id_attr, null: false
        foreign_key [id_attr], table, name: fk_name

        Integer :user_id, null: false
        foreign_key [:user_id], :users, name: fk_user

        index [id_attr, :user_id], unique: true, name: idx_name
      end
    end

    def self.uuid_function(migration)
      if migration.class.name.match?(/mysql/i)
        Sequel.function(:UUID)
      elsif migration.class.name.match?(/postgres/i)
        Sequel.function(:get_uuid)
      end
    end

    # Concurrent migrations can take a long time to run, so this helper can be used to override 'max_migration_statement_runtime_in_seconds' for a specific migration.
    # REF: https://www.postgresql.org/docs/current/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY
    def self.with_concurrent_timeout(db, &block)
      concurrent_timeout_in_seconds = VCAP::CloudController::Config.config&.get(:migration_psql_concurrent_statement_timeout_in_seconds)
      concurrent_timeout_in_milliseconds = if concurrent_timeout_in_seconds.nil? || concurrent_timeout_in_seconds <= 0
                                             PSQL_DEFAULT_STATEMENT_TIMEOUT
                                           else
                                             concurrent_timeout_in_seconds * 1000
                                           end

      if db.database_type == :postgres
        original_timeout = db.fetch("select setting from pg_settings where name = 'statement_timeout'").first[:setting]
        db.run("SET statement_timeout TO #{concurrent_timeout_in_milliseconds}")
      end
      block.call
    ensure
      db.run("SET statement_timeout TO #{original_timeout}") if original_timeout
    end

    def self.logger
      Steno.logger('cc.db.migrations')
    end
  end
end
