require "repositories/runtime/app_event_repository"
require "repositories/runtime/space_event_repository"
require "cloud_controller/rest_controller/object_renderer"
require "cloud_controller/rest_controller/paginated_collection_renderer"

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
        @health_manager_client ||= HealthManagerClient.new(@message_bus)
      else
        @health_manager_client ||= HM9000Client.new(@message_bus, @config)
      end
    end

    def task_client
      @task_client ||= TaskClient.new(message_bus, blobstore_url_generator)
    end

    def droplet_blobstore
      droplets = config.fetch(:droplets)
      cdn_uri = droplets.fetch(:cdn, nil) && droplets.fetch(:cdn).fetch(:uri, nil)
      droplet_cdn = Cdn.make(cdn_uri)

      Blobstore::Client.new(
        droplets.fetch(:fog_connection),
        droplets.fetch(:droplet_directory_key),
        droplet_cdn
      )
    end

    def buildpack_cache_blobstore
      droplets = config.fetch(:droplets)
      cdn_uri = droplets.fetch(:cdn, nil) && droplets.fetch(:cdn).fetch(:uri, nil)
      droplet_cdn = Cdn.make(cdn_uri)

      Blobstore::Client.new(
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

      Blobstore::Client.new(
        packages.fetch(:fog_connection),
        packages.fetch(:app_package_directory_key),
        package_cdn
      )
    end

    def global_app_bits_cache
      resource_pool = config.fetch(:resource_pool)
      cdn_uri = resource_pool.fetch(:cdn, nil) && resource_pool.fetch(:cdn).fetch(:uri, nil)
      app_bit_cdn = Cdn.make(cdn_uri)

      Blobstore::Client.new(
        resource_pool.fetch(:fog_connection),
        resource_pool.fetch(:resource_directory_key),
        app_bit_cdn
      )
    end

    def buildpack_blobstore
      Blobstore::Client.new(
        config[:buildpacks][:fog_connection],
        config[:buildpacks][:buildpack_directory_key] || "cc-buildpacks"
      )
    end

    def upload_handler
      @upload_handler ||= UploadHandler.new(config)
    end

    def blobstore_url_generator
      connection_options = {
        blobstore_host: config[:external_host],
        blobstore_port: config[:external_port],
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

    def app_event_repository
      @app_event_repository ||= Repositories::Runtime::AppEventRepository.new
    end

    def space_event_repository
      Repositories::Runtime::SpaceEventRepository.new
    end

    def object_renderer
      eager_loader = VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer   = VCAP::CloudController::RestController::PreloadedObjectSerializer.new

      VCAP::CloudController::RestController::ObjectRenderer.new(eager_loader, serializer, {
        max_inline_relations_depth: config[:renderer][:max_inline_relations_depth],
      })
    end

    def paginated_collection_renderer
      eager_loader = VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer   = VCAP::CloudController::RestController::PreloadedObjectSerializer.new

      VCAP::CloudController::RestController::PaginatedCollectionRenderer.new(eager_loader, serializer, {
        max_results_per_page:       config[:renderer][:max_results_per_page],
        default_results_per_page:   config[:renderer][:default_results_per_page],
        max_inline_relations_depth: config[:renderer][:max_inline_relations_depth],
      })
    end

    def entity_only_paginated_collection_renderer
      eager_loader = VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer   = VCAP::CloudController::RestController::EntityOnlyPreloadedObjectSerializer.new

      VCAP::CloudController::RestController::PaginatedCollectionRenderer.new(eager_loader, serializer, {
        max_results_per_page:       config[:renderer][:max_results_per_page],
        default_results_per_page:   config[:renderer][:default_results_per_page],
        max_inline_relations_depth: config[:renderer][:max_inline_relations_depth],
      })
    end

    private

    attr_reader :config, :message_bus
  end
end
