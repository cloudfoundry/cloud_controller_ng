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

    def package_blob_store
      packages = config.fetch(:packages)
      package_cdn = Cdn.new(packages[:cdn].fetch(:uri, nil)) if packages.fetch(:cdn, nil)

      BlobStore.new(
        packages.fetch(:fog_connection),
        packages.fetch(:app_package_directory_key),
        package_cdn
      )
    end

    def global_app_bits_cache
      resource_pool = config.fetch(:resource_pool)
      app_bit_cdn = Cdn.new(resource_pool[:cdn].fetch(:uri, nil)) if resource_pool.fetch(:cdn, nil)

      BlobStore.new(
        resource_pool.fetch(:fog_connection),
        resource_pool.fetch(:resource_directory_key),
        app_bit_cdn
      )
    end

    private

    attr_reader :config, :message_bus
  end
end
