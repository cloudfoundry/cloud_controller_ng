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
      patch_sqlite if using_sqlite

      db = Sequel.connect(opts[:database], connection_options)
      db.logger = logger
      db.sql_log_level = opts[:log_level] || :debug2
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

    def self.patch_sqlite
      return if @patched_sqlite
      @patched_sqlite = true

      require "sequel"
      require "sequel/adapters/sqlite"

      Sequel::SQLite::Database.class_eval do
        def connect(server)
          opts = server_opts(server)
          opts[:database] = ":memory:" if blank_object?(opts[:database])
          db = ::SQLite3::Database.new(opts[:database])
          db.busy_handler do |retries|
            Steno.logger("db.patch").debug "SQLITE BUSY, retry ##{retries}"
            sleep(0.1)
            retries < 20
          end

          connection_pragmas.each { |s| log_yield(s) { db.execute_batch(s) } }

          class << db
            attr_reader :prepared_statements
          end
          db.instance_variable_set(:@prepared_statements, {})
          db
        end
      end
    end
  end
end

Sequel.extension :pagination
Sequel.extension :inflector
Sequel::Model.raise_on_typecast_failure = false

Sequel::Model.plugin :association_dependencies
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
