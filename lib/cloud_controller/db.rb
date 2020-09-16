require 'sequel'
require 'cloud_controller/db_migrator'
require 'cloud_controller/db_connection/options_factory'
require 'cloud_controller/db_connection/finalizer'

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
      end
      db.default_collate = 'utf8_bin' if db.database_type == :mysql
      add_connection_validator_extension(db, opts)
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
    val = super(type).deep_dup
    val[:message] = type

    val
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
    def self.timestamps(migration, table_key)
      created_at_idx = "#{table_key}_created_at_index".to_sym if table_key
      updated_at_idx = "#{table_key}_updated_at_index".to_sym if table_key
      migration.Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      migration.Timestamp :updated_at
      migration.index :created_at, name: created_at_idx
      migration.index :updated_at, name: updated_at_idx
    end

    def self.guid(migration, table_key)
      guid_idx = "#{table_key}_guid_index".to_sym if table_key
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

      migration.foreign_key [:resource_guid], foreign_resource_table_key, key: :guid, name: "fk_#{table_key}_resource_guid".to_sym
      migration.index [:resource_guid], name: "fk_#{table_key}_resource_guid_index".to_sym
      migration.index [:key_prefix, :key_name, :value], name: "#{table_key}_compound_index".to_sym
    end

    def self.annotations_common(migration, table_key, foreign_resource_table_key)
      migration.String :resource_guid, size: 255
      migration.String :key_prefix, size: 253
      migration.String :key, size: 1000
      migration.String :value, size: 5000

      migration.foreign_key [:resource_guid], foreign_resource_table_key, key: :guid, name: "fk_#{table_key}_resource_guid".to_sym
      migration.index [:resource_guid], name: "fk_#{table_key}_resource_guid_index".to_sym
    end

    def self.create_permission_table(migration, name, name_short, permission)
      name = name.to_s
      join_table = "#{name.pluralize}_#{permission}".to_sym
      join_table_short = "#{name_short}_#{permission}".to_sym
      id_attr = "#{name}_id".to_sym
      idx_name = "#{name_short}_#{permission}_idx".to_sym
      fk_name = "#{join_table_short}_#{name_short}_fk".to_sym
      fk_user = "#{join_table_short}_user_fk".to_sym
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
  end
end
