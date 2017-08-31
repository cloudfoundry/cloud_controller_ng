require 'support/bootstrap/db_config'
require 'support/paths'

I18n.enforce_available_locales = false # avoid deprecation warning

module TestConfig
  class << self
    def override(overrides)
      @config_instance = load(overrides)
      @config = @config_instance.config_hash
      @config_instance
    end

    def reset
      override({})
    end

    def config
      @config ||= config_instance.config_hash
    end

    def config_instance
      @config_instance ||= load
    end

    private

    def load(overrides={})
      config_hash = defaults.merge(overrides)
      config = VCAP::CloudController::Config.new(config_hash)
      VCAP::CloudController::Config.instance_variable_set(:@instance, config)
      configure_components(config)
      config
    end

    def defaults
      config_file = File.join(Paths::CONFIG, 'cloud_controller.yml')
      config_hash = VCAP::CloudController::Config.load_from_file(config_file).config_hash

      config_hash.update(
        nginx: { use_nginx: true },
        resource_pool: {
          resource_directory_key: 'spec-cc-resources',
          fog_connection: {
            blobstore_timeout: 5,
            provider: 'AWS',
            aws_access_key_id: 'fake_aws_key_id',
            aws_secret_access_key: 'fake_secret_access_key',
          },
        },
        packages: {
          app_package_directory_key: 'cc-packages',
          fog_connection: {
            blobstore_timeout: 5,
            provider: 'AWS',
            aws_access_key_id: 'fake_aws_key_id',
            aws_secret_access_key: 'fake_secret_access_key',
          },
        },
        droplets: {
          droplet_directory_key: 'cc-droplets',
          fog_connection: {
            blobstore_timeout: 5,
            provider: 'AWS',
            aws_access_key_id: 'fake_aws_key_id',
            aws_secret_access_key: 'fake_secret_access_key',
          },
        },

        db: DbConfig.new.config,
      )

      config_hash.deep_merge!(uaa: { internal_url: 'https://uaa.service.cf.internal' })

      config_hash
    end

    def configure_components(config)
      # Always enable Fog mocking (except when using a local provider, which Fog can't mock).
      res_pool_connection_provider = config.get(:resource_pool, :fog_connection)[:provider].downcase
      packages_connection_provider = config.get(:packages, :fog_connection)[:provider].downcase
      Fog.mock! unless res_pool_connection_provider == 'local' || packages_connection_provider == 'local'

      # reset dependency locator
      dependency_locator = CloudController::DependencyLocator.instance
      dependency_locator.reset(config)
      config.configure_components

      stacks_file = File.join(Paths::FIXTURES, 'config/stacks.yml')
      VCAP::CloudController::Stack.configure(stacks_file)
    end
  end
end
