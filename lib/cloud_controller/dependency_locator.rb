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
      package_cdn = Cdn.new(config[:packages][:cdn][:uri]) if config[:packages][:cdn]

      BlobStore.new(
        config[:packages][:fog_connection],
        config[:packages][:app_package_directory_key],
        package_cdn
      )
    end

    def global_app_bits_cache
      app_bit_cdn = Cdn.new(config[:resource_pool][:cdn][:uri]) if config[:resource_pool][:cdn]

      BlobStore.new(
        config[:resource_pool][:fog_connection],
        config[:resource_pool][:resource_directory_key],
        app_bit_cdn
      )
    end

    private

    attr_reader :config, :message_bus
  end
end
