require "vcap/sequel_varz"
require "delayed_job_active_record"

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
    def self.connect(logger, opts, active_record_db_opts)
      connection_options = { :sql_mode => [:strict_trans_tables, :strict_all_tables, :no_zero_in_date] }
      [:max_connections, :pool_timeout].each do |key|
        connection_options[key] = opts[key] if opts[key]
      end

      if opts[:database].index("mysql") == 0
        connection_options[:charset] = "utf8"
      end

      using_sqlite = opts[:database].index("sqlite://") == 0
      if using_sqlite
        require "vcap/sequel_sqlite_monkeypatch"
      end

      active_record_connect(logger, active_record_db_opts[:database])

      db = Sequel.connect(opts[:database], connection_options)
      db.logger = logger
      db.sql_log_level = opts[:log_level] || :debug2

      if db.database_type == :mysql
        # TODO: should be utf8_unicode_ci till story https://www.pivotaltracker.com/story/show/51039807
        Sequel::MySQL.default_collate = "utf8_bin"
      end

      validate_sqlite_version(db) if using_sqlite
      VCAP::SequelVarz.start(db)
      db
    end

    def self.apply_migrations(db, opts = {})
      Sequel.extension :migration
      require "vcap/sequel_case_insensitive_string_monkeypatch"
      migrations_dir = File.expand_path("../../../db", __FILE__)
      sequel_migrations = File.join(migrations_dir, "migrations")
      Sequel::Migrator.run(db, sequel_migrations, opts)

      active_record_migrations = File.join(migrations_dir, "ar_migrations")

      ActiveRecord::Migrator.migrate(active_record_migrations, nil)
    end

    private

    def self.validate_sqlite_version(db)
      return if @validated_sqlite
      @validate_sqlite = true

      min_version = "3.6.19"
      version = db.fetch("SELECT sqlite_version()").first[:"sqlite_version()"]
      unless validate_version_string(min_version, version)
        puts <<EOF
The CC models require sqlite version >= #{min_version} but you are
running #{version} On OSX, you will might to install the sqlite
gem against an upgraded sqlite (from source, homebrew, macports, etc)
and not the system sqlite. You can do so with a command
such as:

  gem install sqlite3 -- --with-sqlite3-include=/usr/local/include/ \
                         --with-sqlite3-lib=/usr/local/lib

EOF
        exit 1
      end
    end

    def self.active_record_connect(logger, database_uri)
      return ActiveRecord::Base.connection if ActiveRecord::Base.connected?

      if database_uri =~ /^sqlite/
        options = {
          adapter: "sqlite3",
          database: database_uri.gsub(%r{^sqlite://}, '')
        }
      else
        uri = URI.parse(database_uri)
        options = {
          username: uri.user,
          password: uri.password,
          host: uri.host,
          port: uri.port,
          adapter: uri.scheme,
          database: uri.path[1..-1]
        }
      end

      ActiveRecord::Base.establish_connection(options)
      ActiveRecord::Base.logger = logger
      ActiveRecord::Base.connection
    end

    def self.validate_version_string(min_version, version)
      min_fields = min_version.split(".").map { |v| v.to_i }
      ver_fields = version.split(".").map { |v| v.to_i }

      (0..2).each do |i|
        return true  if ver_fields[i] > min_fields[i]
        return false if ver_fields[i] < min_fields[i]
      end

      return true
    end
  end
end

Sequel.extension :inflector
Sequel::Model.raise_on_typecast_failure = false

Sequel::Model.plugin :association_dependencies
Sequel::Model.plugin :dirty
Sequel::Model.plugin :timestamps
Sequel::Model.plugin :validation_helpers

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
# TODO: decide on a better way of mixing this in to whatever
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
