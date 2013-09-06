module CloudController
  class DependencyLocator
    include Singleton
    include VCAP::CloudController

    def initialize(config = Config.config, message_bus = Config.message_bus)
      @config = config
      @message_bus = message_bus
    end

    def health_manager_client
      @health_manager_client ||= HealthManagerClient.new(message_bus)
    end

    def task_client
      @task_client ||= TaskClient.new(message_bus)
    end

    def droplet_blob_store
      blob_store :droplets, :droplet_directory_key, "cc-droplets"
    end

    def package_blob_store
      blob_store :packages, :app_package_directory_key
    end

    def global_app_bits_cache
      blob_store :resource_pool, :resource_directory_key
    end

    private

    def blob_store(config_key, directory_key, default_directory=nil)
      c = config.fetch(config_key)
      BlobStore.new(
        c.fetch(:fog_connection),
        c.fetch(directory_key, default_directory),
        make_cdn(c)
      )
    end

    def make_cdn(config)
      uri = config.fetch(:cdn, nil) && config.fetch(:cdn).fetch(:uri, nil)
      Cdn.make(uri)
    end

    attr_reader :config, :message_bus
  end
end
