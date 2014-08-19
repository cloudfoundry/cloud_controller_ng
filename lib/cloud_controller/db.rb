module VCAP::CloudController
  class DB
    # Setup a Sequel connection pool
    #
    # @param [Logger]  Logger to pass to Sequel
    #
    # @option opts [String]  :database Database connection string
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
      connection_options = { :sql_mode => [:strict_trans_tables, :strict_all_tables, :no_zero_in_date] }
      [:max_connections, :pool_timeout].each do |key|
        connection_options[key] = opts[key] if opts[key]
      end

      if opts[:database].index("mysql") == 0
        connection_options[:charset] = "utf8"
      end

      db = Sequel.connect(opts[:database], connection_options)
      db.logger = logger
      db.sql_log_level = opts[:log_level] || :debug2

      if db.database_type == :mysql
        Sequel::MySQL.default_collate = "utf8_bin"
      end

      db
    end

    def self.load_models(db_config, logger)
      connect(db_config, logger)
      require "models"
      require "delayed_job_sequel"
    end
  end
end

Sequel.extension :inflector
Sequel::Model.raise_on_typecast_failure = false

Sequel::Model.plugin :association_dependencies
Sequel::Model.plugin :dirty
Sequel::Model.plugin :timestamps
Sequel::Model.plugin :validation_helpers

Sequel::Database.extension(:current_datetime_timestamp)

# monkey patch sequel to make it easier to map validation failures to custom
# exceptions, e.g.
#
# rescue Sequel::ValidationFailed => e
#   if e.errors.on(:some_attribute).include(:unique)
#     ...
#
Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS.each do |k, v|
  Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS[k][:message] = k
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
      migration.Timestamp :created_at, :null => false
      migration.Timestamp :updated_at
      migration.index :created_at, :name => created_at_idx
      migration.index :updated_at, :name => updated_at_idx
    end

    def self.guid(migration, table_key)
      guid_idx = "#{table_key}_guid_index".to_sym if table_key
      migration.String :guid, :null => false
      migration.index :guid, :unique => true, :name => guid_idx
    end

    def self.common(migration, table_key = nil)
      migration.primary_key :id
      guid(migration, table_key)
      timestamps(migration, table_key)
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
        Integer id_attr, :null => false
        foreign_key [id_attr], table, :name => fk_name

        Integer :user_id, :null => false
        foreign_key [:user_id], :users, :name => fk_user

        index [id_attr, :user_id], :unique => true, :name => idx_name
      end
    end
  end
end
