require 'support/bootstrap/db_config'
require 'support/paths'
require 'cloud_controller/config'

module TestConfig
  class << self
    def context
      @context || :api
    end

    def context=(context)
      @context = context
    end

    def override(**overrides)
      @config_instance = load(**overrides)
    end

    def reset
      override({})
    end

    def config
      config_instance.config_hash
    end

    def config_instance
      @config_instance ||= load
    end

    private

    def load(**overrides)
      config_hash = defaults.merge(overrides)
      config = VCAP::CloudController::Config.new(config_hash, context: context)
      VCAP::CloudController::Config.instance_variable_set(:@instance, config)
      configure_components(config)
      config
    end

    def defaults
      config_file = File.join(Paths::CONFIG, 'cloud_controller.yml')
      config_hash = VCAP::CloudController::Config.load_from_file(config_file, context: context).config_hash

      fog_connection = {
        blobstore_timeout: 5,
        provider: 'AWS',
        aws_access_key_id: 'fake_aws_key_id',
        aws_secret_access_key: 'fake_secret_access_key',
      }

      config_hash.update(
        nginx: { use_nginx: true },
        resource_pool: {
          resource_directory_key: 'spec-cc-resources',
          fog_connection: fog_connection,
        },
        packages: {
          app_package_directory_key: 'cc-packages',
          fog_connection: fog_connection,
          max_valid_packages_stored: 42,
        },
        buildpacks: {
          buildpack_directory_key: 'cc-buildpacks',
          fog_connection: fog_connection,
        },
        droplets: {
          droplet_directory_key: 'cc-droplets',
          fog_connection: fog_connection,
          max_staged_droplets_stored: 42,
        },
        db: DbConfig.new.config,
      )

      config_hash.deep_merge!(uaa: { internal_url: 'https://uaa.service.cf.internal' })

      config_hash
    end

    def configure_components(config)
      # Always enable Fog mocking (except when using a local provider, which Fog can't mock).
      if context != :route_syncer && context != :deployment_updater
        res_pool_connection_provider = config.get(:resource_pool, :fog_connection)[:provider].downcase
        packages_connection_provider = config.get(:packages, :fog_connection)[:provider].downcase
        Fog.mock! unless res_pool_connection_provider == 'local' || packages_connection_provider == 'local'
      end

      # reset dependency locator
      dependency_locator = CloudController::DependencyLocator.instance
      dependency_locator.reset(config)
      config.configure_components

      stacks_file = File.join(Paths::FIXTURES, 'config/stacks.yml')
      VCAP::CloudController::Stack.configure(stacks_file)
    end
  end
end
