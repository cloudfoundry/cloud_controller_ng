require 'cloud_controller/account_capacity'
require 'uri'
require 'cloud_controller/backends/stagers'
require 'cloud_controller/backends/runners'
require 'cloud_controller/index_stopper'
require 'cloud_controller/backends/instances_reporters'
require 'repositories/service_event_repository'
require 'cloud_controller/config_schemas/api_schema'
require 'cloud_controller/config_schemas/clock_schema'
require 'cloud_controller/config_schemas/migrate_schema'
require 'cloud_controller/config_schemas/route_syncer_schema'
require 'cloud_controller/config_schemas/worker_schema'
require 'cloud_controller/config_schemas/deployment_updater_schema'
require 'cloud_controller/config_schemas/rotatate_database_key_schema'

module VCAP::CloudController
  class Config
    class InvalidConfigPath < StandardError
    end

    class << self
      def load_from_file(file_name, context: :api)
        schema_class = schema_class_for_context(context)
        config_from_file = schema_class.from_file(file_name)
        hash = merge_defaults(config_from_file)
        @instance = new(hash, context: context)
      end

      def config
        @instance
      end

      def schema_class_for_context(context)
        const_get("VCAP::CloudController::ConfigSchemas::#{context.to_s.camelize}Schema")
      end

      private

      def merge_defaults(config)
        config[:db] ||= {}
        ensure_config_has_database_parts(config)
        sanitize(config)
      end

      # ensure_config_has_database_parts
      # At some point we want to drop the database connection string
      # and rename the :database_parts field to :database, so deprecate if the parts is missing
      def ensure_config_has_database_parts(config)
        abort_no_db_connection! if ENV['DB_CONNECTION_STRING'].nil? && \
          config[:db][:database].nil? && config[:db][:database_parts].nil?
        if config[:db][:database_parts].nil?
          if config[:db][:database]
            warn('Config should be updated to include cc.db.database_parts')
          else
            config[:db][:database] = ENV['DB_CONNECTION_STRING']
          end
          config[:db][:database_parts] = DatabasePartsParser.database_parts_from_connection(config[:db][:database])
        else
          config[:db][:database] ||= ENV['DB_CONNECTION_STRING'] || DatabasePartsParser.connection_from_database_parts(config[:db][:database_parts])
        end
      end

      def abort_no_db_connection!
        abort('No database connection set (consider setting DB_CONNECTION_STRING)')
      end

      def sanitize(config)
        if config.key?(:staging)
          auth = config[:staging][:auth]
          auth[:user] = escape_userinfo(auth[:user]) unless valid_in_userinfo?(auth[:user])
          auth[:password] = escape_password(auth[:password]) unless valid_in_userinfo?(auth[:password])
        end
        config
      end

      def escape_password(value)
        escape_userinfo(value).gsub(/\"/, '%22')
      end

      def escape_userinfo(value)
        CGI.escape(value)
      end

      def valid_in_userinfo?(value)
        URI::REGEXP::PATTERN::USERINFO.match(value)
      end
    end

    attr_reader :config_hash

    def initialize(config_hash, context: :api)
      @config_hash = config_hash
      @schema_class = self.class.schema_class_for_context(context)
    end

    def configure_components
      Encryptor.db_encryption_key = get(:db_encryption_key)

      if get(:database_encryption)
        Encryptor.database_encryption_keys = get(:database_encryption)[:keys]
        Encryptor.current_encryption_key_label = get(:database_encryption)[:current_key_label]
      end

      dependency_locator = CloudController::DependencyLocator.instance
      dependency_locator.config = self

      run_initializers

      ProcessObserver.configure(dependency_locator.stagers, dependency_locator.runners)
      InternalApi.configure(self)
      @schema_class.configure_components(self)
    end

    def get(*keys)
      invalid_config_path!(keys) unless valid_config_path?(keys, @schema_class.schema)

      HashUtils.dig(config_hash, *keys)
    end

    def set(key, value)
      config_hash[key] = value
    end

    def valid_config_path?(keys, some_schema)
      keys.each do |key|
        if some_schema.is_a?(Membrane::Schemas::Record) && some_schema.schemas.keys.include?(key)
          some_schema = some_schema.schemas[key]
        else
          invalid_config_path!(keys)
        end
      end
    end

    private

    def invalid_config_path!(keys)
      raise InvalidConfigPath.new(%("#{keys.join('.')}" is not a valid config key))
    end

    def run_initializers
      return if @initialized
      run_initializers_in_directory('../../../config/initializers/*.rb')
      if @config_hash[:newrelic_enabled]
        require 'newrelic_rpm'

        # We need to explicitly initialize NewRelic before running our initializers
        # When Rails is present, NewRelic adds itself to the Rails initializers instead
        # of initializing immediately.

        opts = if (Rails.env.test? || Rails.env.development?) && !ENV['NRCONFIG']
                 { env: ENV['NEW_RELIC_ENV'] || 'production', monitor_mode: false }
               else
                 { env: ENV['NEW_RELIC_ENV'] || 'production' }
               end

        NewRelic::Agent.manual_start(opts)
        run_initializers_in_directory('../../../config/newrelic/initializers/*.rb')
      end
      @initialized = true
    end

    def run_initializers_in_directory(path)
      Dir.glob(File.expand_path(path, __FILE__)).each do |file|
        require file
        method = File.basename(file).sub('.rb', '').tr('-', '_')
        CCInitializers.send(method, @config_hash)
      end
    end
  end
end
