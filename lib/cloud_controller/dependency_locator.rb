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

    def package_blobstore
      packages = config.fetch(:packages)
      cdn_uri = packages.fetch(:cdn, nil) && packages.fetch(:cdn).fetch(:uri, nil)
      package_cdn = Cdn.make(cdn_uri)

      Blobstore.new(
        packages.fetch(:fog_connection),
        packages.fetch(:app_package_directory_key),
        package_cdn
      )
    end

    def global_app_bits_cache
      resource_pool = config.fetch(:resource_pool)
      cdn_uri = resource_pool.fetch(:cdn, nil) && resource_pool.fetch(:cdn).fetch(:uri, nil)
      app_bit_cdn = Cdn.make(cdn_uri)

      Blobstore.new(
        resource_pool.fetch(:fog_connection),
        resource_pool.fetch(:resource_directory_key),
        app_bit_cdn
      )
    end

    def buildpack_blobstore
      @buildpack_blobstore ||=
          Blobstore.new(config[:buildpacks][:fog_connection],
                        config[:buildpacks][:buildpack_directory_key] || "cc-buildpacks")
    end

    def upload_handler
      @upload_handler ||= UploadHandler.new(config)
    end

    private

    attr_reader :config, :message_bus
  end
end
