module CloudController
  class DependencyLocator
    include Singleton
    include VCAP::CloudController

    def initialize(config = VCAP::CloudController::Config.config, message_bus = VCAP::CloudController::Config.message_bus)
      @config = config
      @message_bus = message_bus
    end

    def health_manager_client
      if @config[:hm9000_noop]
        @health_manager_client ||= HealthManagerClient.new(message_bus)
      else
        @health_manager_client ||= HM9000Client.new(@config)
      end
    end

    def task_client
      @task_client ||= TaskClient.new(message_bus, blobstore_url_generator)
    end

    def droplet_blobstore
      droplets = config.fetch(:droplets)
      cdn_uri = droplets.fetch(:cdn, nil) && droplets.fetch(:cdn).fetch(:uri, nil)
      droplet_cdn = Cdn.make(cdn_uri)

      Blobstore.new(
        droplets.fetch(:fog_connection),
        droplets.fetch(:droplet_directory_key),
        droplet_cdn
      )
    end

    def buildpack_cache_blobstore
      droplets = config.fetch(:droplets)
      cdn_uri = droplets.fetch(:cdn, nil) && droplets.fetch(:cdn).fetch(:uri, nil)
      droplet_cdn = Cdn.make(cdn_uri)

      Blobstore.new(
        droplets.fetch(:fog_connection),
        droplets.fetch(:droplet_directory_key),
        droplet_cdn,
        "buildpack_cache"
      )
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
      Blobstore.new(
        config[:buildpacks][:fog_connection],
        config[:buildpacks][:buildpack_directory_key] || "cc-buildpacks"
      )
    end

    def upload_handler
      @upload_handler ||= UploadHandler.new(config)
    end

    def blobstore_url_generator
      connection_options = {
        blobstore_host: config[:bind_address],
        blobstore_port: config[:port],
        user: config[:staging][:auth][:user],
        password: config[:staging][:auth][:password]
      }
      BlobstoreUrlGenerator.new(
        connection_options,
        package_blobstore,
        buildpack_cache_blobstore,
        buildpack_blobstore,
        droplet_blobstore
      )
    end

    private

    attr_reader :config, :message_bus
  end
end
