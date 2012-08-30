# Copyright (c) 2009-2012 VMware, Inc.

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
    def self.connect(logger, opts)
      connection_options = {}
      [:max_connections, :pool_timeout].each do |key|
        connection_options[key] = opts[key.to_s]
      end

      using_sqlite = opts[:database].index("sqlite://") == 0
      if using_sqlite
        require "vcap/sequel_sqlite_monkeypatch"
      end

      db = Sequel.connect(opts[:database], connection_options)
      db.logger = logger
      db.sql_log_level = opts[:log_level] || :debug2

      validate_sqlite_version(db) if using_sqlite
      db
    end

    # Apply migrations to a database
    #
    # @param [Sequel::Database]  Database to apply migrations to
    def self.apply_migrations(db)
      Sequel.extension :migration
      migrations_dir ||= File.expand_path("../../../db/migrations", __FILE__)
      Sequel::Migrator.apply(db, migrations_dir)
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

Sequel.extension :pagination
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
    def self.timestamps(migration)
      migration.Timestamp :created_at, :null => false, :index => true
      migration.Timestamp :updated_at, :index => true
    end

    def self.guid(migration)
      migration.String :guid, :null => false, :index => true, :unique => true
    end

    def self.common(migration)
      migration.primary_key :id
      guid(migration)
      timestamps(migration)
    end

    def self.create_permission_table(migration, name, permission)
      name = name.to_s
      join_table = "#{name.pluralize}_#{permission}".to_sym
      id_attr = "#{name}_id".to_sym
      table = name.pluralize.to_sym

      migration.create_table(join_table) do
        foreign_key id_attr, table, :null => false
        foreign_key :user_id, :users, :null => false
        index [id_attr, :user_id], :unique => true
      end
    end
  end
end
