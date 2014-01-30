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

      using_sqlite = opts[:database].index("sqlite://") == 0
      if using_sqlite
        require "vcap/sequel_sqlite_monkeypatch"
      end

      db = Sequel.connect(opts[:database], connection_options)
      db.logger = logger
      db.sql_log_level = opts[:log_level] || :debug2

      if db.database_type == :mysql
        Sequel::MySQL.default_collate = "utf8_bin"
      end

      validate_sqlite_version(db) if using_sqlite
      db
    end

    def self.load_models(db_config, logger)
      connect(db_config, logger)
      require "models/runtime/app_bits_package"
      require "models/runtime/app_usage_event"
      require "models/runtime/auto_detection_buildpack"
      require "models/runtime/billing_event"
      require "models/runtime/organization_start_event"
      require "models/runtime/app_start_event"
      require "models/runtime/app_stop_event"
      require "models/runtime/app_event"
      require "models/runtime/app"
      require "models/runtime/droplet"
      require "models/runtime/buildpack"
      require "models/runtime/domain"
      require "models/runtime/shared_domain"
      require "models/runtime/private_domain"
      require "models/runtime/event"
      require "models/runtime/git_based_buildpack"
      require "models/runtime/organization"
      require "models/runtime/organization_routes"
      require "models/runtime/quota_definition"
      require "models/runtime/quota_constraints/max_routes_policy"
      require "models/runtime/quota_constraints/max_service_instances_policy"
      require "models/runtime/route"
      require "models/runtime/task"
      require "models/runtime/space"
      require "models/runtime/stack"
      require "models/runtime/user"

      require "models/services/service"
      require "models/services/service_auth_token"
      require "models/services/service_binding"
      require "models/services/service_instance"
      require "models/services/managed_service_instance"
      require "models/services/user_provided_service_instance"
      require "models/services/service_broker"
      require "models/services/service_broker/v1"
      require "models/services/service_broker/v1/client"
      require "models/services/service_broker/v1/http_client"
      require "models/services/service_broker/v2"
      require "models/services/service_broker/v2/client"
      require "models/services/service_broker/v2/http_client"
      require "models/services/service_broker/user_provided"
      require "models/services/service_broker/user_provided/client"
      require "models/services/service_broker_registration"
      require "models/services/service_plan"
      require "models/services/service_plan_visibility"
      require "models/services/service_base_event"
      require "models/services/service_create_event"
      require "models/services/service_delete_event"

      require "models/job"

      require "delayed_job_sequel"
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
