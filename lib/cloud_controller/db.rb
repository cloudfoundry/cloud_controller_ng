# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class DB
    # Setup a Sequel connection pool
    #
    # @param [Logger]  Logger to pass to Sequel
    #
    # @options opts [String]  :database Database connection string
    #
    # @options opts [Symbol]  :log_level VCAP::Logger log level
    #
    # @option opts  [Integer] :max_connections The maximum number of
    # connections the connection pool will open (default 4)
    #
    # @option opts [Integer]  :pool_timeout The amount of seconds to wait to
    # acquire a connection before raising a PoolTimeoutError (default 5)
    #
    # @return [Sequel::Database]
    def self.connect(logger, options)
      connection_options = {}
      [:max_connections, :pool_timeout].each do |key|
        connection_options[key] = options[key.to_s]
      end

      db = Sequel.connect(options[:database], connection_options)
      db.logger = logger
      db.sql_log_level = options[:log_level] || :warn
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
  end
end

Sequel.extension :inflector
Sequel::Model.raise_on_typecast_failure = false

Sequel::Model.plugin :timestamps
Sequel::Model.plugin :validation_helpers

# monkey patch sequel to make it easier to map validation vailures to custom
# exceptions, e.g.
#
# rescue Sequel::ValidationFailed => e
#   if e.errors.on(:some_attribute).include(:unique)
#     ...
#
Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS.each do |k, v|
  Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS[k][:message] = k
end
