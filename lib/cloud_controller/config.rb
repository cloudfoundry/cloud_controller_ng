require 'cloud_controller/account_capacity'
require 'uri'
require 'cloud_controller/backends/stagers'
require 'cloud_controller/backends/runners'
require 'cloud_controller/index_stopper'
require 'cloud_controller/backends/instances_reporters'
require 'repositories/service_event_repository'
require 'cloud_controller/config_schemas/api_schema'
require 'cloud_controller/config_schemas/clock_schema'
require 'cloud_controller/config_schemas/worker_schema'
require 'cloud_controller/config_schemas/migrate_schema'

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
        const_get("VCAP::CloudController::ConfigSchemas::#{context.capitalize}Schema")
      end

      private

      def merge_defaults(config)
        config[:stacks_file] ||= File.join(config_dir, 'stacks.yml')
        config[:maximum_app_disk_in_mb] ||= 2048
        config[:request_timeout_in_seconds] ||= 900
        config[:directories] ||= {}
        config[:skip_cert_verify] = false if config[:skip_cert_verify].nil?
        config[:app_bits_upload_grace_period_in_seconds] ||= 0
        config[:db] ||= {}
        config[:db][:database] ||= ENV['DB_CONNECTION_STRING']
        config[:default_locale] ||= 'en_US'
        config[:allowed_cors_domains] ||= []
        config[:staging][:minimum_staging_memory_mb] ||= 1024
        config[:staging][:minimum_staging_disk_mb] ||= 4096
        config[:staging][:minimum_staging_file_descriptor_limit] ||= 16384
        config[:broker_client_timeout_seconds] ||= 60
        config[:broker_client_default_async_poll_interval_seconds] ||= 60
        config[:packages][:max_valid_packages_stored] ||= 5
        config[:droplets][:max_staged_droplets_stored] ||= 5
        config[:bits_service] ||= { enabled: false }
        config[:rate_limiter] ||= { enabled: false }
        config[:rate_limiter][:general_limit] ||= 2000
        config[:rate_limiter][:reset_interval_in_minutes] ||= 60
        config[:perm] ||= { enabled: false }

        unless config.key?(:users_can_select_backend)
          config[:users_can_select_backend] = true
        end

        sanitize(config)
      end

      def config_dir
        @config_dir ||= File.expand_path('../../config', __dir__)
      end

      def sanitize(config)
        sanitize_grace_period(config)
        sanitize_staging_auth(config)
        sanitize_diego_properties(config)

        config
      end

      def sanitize_diego_properties(config)
        pid_limit = HashUtils.dig(config, :diego, :pid_limit)
        if pid_limit
          config[:diego][:pid_limit] = 0 if pid_limit < 0
        end
      end

      def sanitize_grace_period(config)
        grace_period = config[:app_bits_upload_grace_period_in_seconds]
        config[:app_bits_upload_grace_period_in_seconds] = 0 if grace_period < 0
      end

      def sanitize_staging_auth(config)
        auth = config[:staging][:auth]
        auth[:user] = escape_userinfo(auth[:user]) unless valid_in_userinfo?(auth[:user])
        auth[:password] = escape_password(auth[:password]) unless valid_in_userinfo?(auth[:password])
      end

      def escape_password(value)
        escape_userinfo(value).gsub(/\"/, '%22')
      end

      def escape_userinfo(value)
        URI.escape(value, "%#{URI::REGEXP::PATTERN::RESERVED}")
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

      if get(:database_encryption_keys)
        Encryptor.database_encryption_keys = get(:database_encryption_keys)[:keys]
        Encryptor.current_encryption_key_label = get(:database_encryption_keys)[:current_key_label]
      end

      dependency_locator = CloudController::DependencyLocator.instance
      dependency_locator.config = self

      run_initializers

      AppObserver.configure(dependency_locator.stagers, dependency_locator.runners)
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
