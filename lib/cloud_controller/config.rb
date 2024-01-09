require 'cloud_controller/account_capacity'
require 'uri'
require 'cloud_controller/backends/stagers'
require 'cloud_controller/backends/runners'
require 'cloud_controller/index_stopper'
require 'cloud_controller/backends/instances_reporters'
require 'repositories/service_event_repository'
require 'cloud_controller/config_schemas/vms/api_schema'
require 'cloud_controller/config_schemas/vms/clock_schema'
require 'cloud_controller/config_schemas/vms/migrate_schema'
require 'cloud_controller/config_schemas/vms/route_syncer_schema'
require 'cloud_controller/config_schemas/vms/worker_schema'
require 'cloud_controller/config_schemas/vms/deployment_updater_schema'
require 'cloud_controller/config_schemas/vms/rotate_database_key_schema'
require 'utils/hash_utils'

module VCAP::CloudController
  class Config
    class InvalidConfigPath < StandardError
    end

    class << self
      def load_from_file(file_name, context: :api, secrets_hash: {})
        config = VCAP::CloudController::YAMLConfig.safe_load_file(file_name)
        load_from_hash(config, context:, secrets_hash:)
      end

      def config
        @instance
      end

      def schema_class_for_context(context, _config)
        module_name = 'Vms'
        const_get("VCAP::CloudController::ConfigSchemas::#{module_name}::#{context.to_s.camelize}Schema")
      end

      def read_file(file_name)
        deep_symbolize_keys_except_in_arrays(VCAP::CloudController::YAMLConfig.safe_load_file(file_name)) || {}
      end

      def load_from_hash(config_hash, context: :api, secrets_hash: {})
        config = deep_symbolize_keys_except_in_arrays(config_hash)
        secrets_hash = deep_symbolize_keys_except_in_arrays(secrets_hash)
        config = config.deep_merge(secrets_hash)

        schema_class = schema_class_for_context(context, config)
        schema_class.validate(config)

        hash = merge_defaults(config)
        @instance = new(hash, context:)
      end

      private

      def deep_symbolize_keys_except_in_arrays(hash)
        return hash unless hash.is_a? Hash

        hash.each.with_object({}) do |(k, v), new_hash|
          new_hash[k.to_sym] = deep_symbolize_keys_except_in_arrays(v)
        end
      end

      def merge_defaults(orig_config)
        config = orig_config.dup
        config[:db] ||= {}
        ensure_config_has_database_parts(config)
        sanitize(config)
      end

      def ensure_config_has_database_parts(config)
        abort_no_db_connection! if ENV['DB_CONNECTION_STRING'].nil? && config[:db][:database].nil?
        config[:db][:db_connection_string] ||= ENV.fetch('DB_CONNECTION_STRING', nil)
        config[:db][:database] ||= DatabasePartsParser.database_parts_from_connection(config[:db][:db_connection_string])
      end

      def abort_no_db_connection!
        abort('No database connection set (consider setting DB_CONNECTION_STRING)')
      end

      def sanitize(config)
        if config.key?(:staging) && config[:staging].key?(:auth)
          auth = config[:staging][:auth]
          auth[:user] = escape_userinfo(auth[:user]) unless valid_in_userinfo?(auth[:user])
          auth[:password] = escape_password(auth[:password]) unless valid_in_userinfo?(auth[:password])
        end
        config
      end

      def escape_password(value)
        escape_userinfo(value).gsub('\"', '%22')
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
      @schema_class = self.class.schema_class_for_context(context, config_hash)
    end

    def configure_components
      Encryptor.db_encryption_key = get(:db_encryption_key)

      if get(:database_encryption)
        Encryptor.database_encryption_keys = get(:database_encryption)[:keys]
        Encryptor.current_encryption_key_label = get(:database_encryption)[:current_key_label]
        Encryptor.pbkdf2_hmac_iterations = get(:database_encryption)[:pbkdf2_hmac_iterations]
      end

      dependency_locator = CloudController::DependencyLocator.instance
      dependency_locator.config = self

      run_initializers

      ProcessObserver.configure(dependency_locator.stagers, dependency_locator.runners)
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
        if some_schema.is_a?(Membrane::Schemas::Record) && some_schema.schemas.key?(key)
          some_schema = some_schema.schemas[key]
        else
          invalid_config_path!(keys)
        end
      end
    end

    def package_image_registry_configured?
      !get(:packages, :image_registry).nil?
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
