require "repositories/runtime/app_event_repository"
require "repositories/runtime/space_event_repository"
require "cloud_controller/rest_controller/object_renderer"
require "cloud_controller/rest_controller/paginated_collection_renderer"
require "cloud_controller/upload_handler"
require "cloud_controller/blob_sender/ngx_blob_sender"
require "cloud_controller/blob_sender/default_blob_sender"
require "cloud_controller/blob_sender/missing_blob_handler"
require "cloud_controller/diego/client"
require "cloud_controller/diego/messenger"
require "cloud_controller/diego/traditional/protocol"

module CloudController
  class DependencyLocator
    include Singleton
    include VCAP::CloudController

    LARGE_COLLECTION_SIZE = 10_000

    attr_writer :config

    def initialize
      @config = VCAP::CloudController::Config.config
      @dependencies = {}
    end

    def register(name, value)
      @dependencies[name] = value
    end

    def health_manager_client
      @dependencies[:health_manager_client] || raise('health_manager_client not set')
    end

    def backends
      @dependencies[:backends] || raise('backends not set')
    end

    def diego_client
      @dependencies[:diego_client] || raise('diego_client not set')
    end

    def upload_handler
      @dependencies[:upload_handler] || raise('upload_handler not set')
    end

    def app_event_repository
      @dependencies[:app_event_repository] || raise('app_event_registry not set')
    end

    def instances_reporter
      @dependencies[:instances_reporter] || raise('instances_reporter not set')
    end

    def droplet_blobstore
      droplets = @config.fetch(:droplets)
      cdn_uri = droplets.fetch(:cdn, nil) && droplets.fetch(:cdn).fetch(:uri, nil)
      droplet_cdn = CloudController::Blobstore::Cdn.make(cdn_uri)

      Blobstore::Client.new(
        droplets.fetch(:fog_connection),
        droplets.fetch(:droplet_directory_key),
        droplet_cdn
      )
    end

    def buildpack_cache_blobstore
      droplets = @config.fetch(:droplets)
      cdn_uri = droplets.fetch(:cdn, nil) && droplets.fetch(:cdn).fetch(:uri, nil)
      droplet_cdn = CloudController::Blobstore::Cdn.make(cdn_uri)

      Blobstore::Client.new(
        droplets.fetch(:fog_connection),
        droplets.fetch(:droplet_directory_key),
        droplet_cdn,
        "buildpack_cache"
      )
    end

    def package_blobstore
      packages = @config.fetch(:packages)
      cdn_uri = packages.fetch(:cdn, nil) && packages.fetch(:cdn).fetch(:uri, nil)
      package_cdn = CloudController::Blobstore::Cdn.make(cdn_uri)

      Blobstore::Client.new(
        packages.fetch(:fog_connection),
        packages.fetch(:app_package_directory_key),
        package_cdn
      )
    end

    def global_app_bits_cache
      resource_pool = @config.fetch(:resource_pool)
      cdn_uri = resource_pool.fetch(:cdn, nil) && resource_pool.fetch(:cdn).fetch(:uri, nil)
      min_file_size = resource_pool[:minimum_size]
      max_file_size = resource_pool[:maximum_size]
      app_bit_cdn = CloudController::Blobstore::Cdn.make(cdn_uri)

      Blobstore::Client.new(
        resource_pool.fetch(:fog_connection),
        resource_pool.fetch(:resource_directory_key),
        app_bit_cdn,
        nil,
        min_file_size,
        max_file_size
      )
    end

    def buildpack_blobstore
      Blobstore::Client.new(
        @config[:buildpacks][:fog_connection],
        @config[:buildpacks][:buildpack_directory_key] || "cc-buildpacks"
      )
    end

    def blobstore_url_generator
      connection_options = {
        blobstore_host: @config[:public_host] ||= @config[:external_host],
        blobstore_port: @config[:external_port],
        user: @config[:staging][:auth][:user],
        password: @config[:staging][:auth][:password]
      }
      Blobstore::UrlGenerator.new(
        connection_options,
        package_blobstore,
        buildpack_cache_blobstore,
        buildpack_blobstore,
        droplet_blobstore
      )
    end

    def space_event_repository
      Repositories::Runtime::SpaceEventRepository.new
    end

    def object_renderer
      eager_loader = VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer   = VCAP::CloudController::RestController::PreloadedObjectSerializer.new

      VCAP::CloudController::RestController::ObjectRenderer.new(eager_loader, serializer, {
        max_inline_relations_depth: @config[:renderer][:max_inline_relations_depth],
      })
    end

    def paginated_collection_renderer
      create_paginated_collection_renderer
    end

    def large_paginated_collection_renderer
      create_paginated_collection_renderer(max_results_per_page: LARGE_COLLECTION_SIZE)
    end

    def entity_only_paginated_collection_renderer
      create_paginated_collection_renderer(serializer: VCAP::CloudController::RestController::EntityOnlyPreloadedObjectSerializer.new)
    end

    def missing_blob_handler
      CloudController::BlobSender::MissingBlobHandler.new
    end

    def blob_sender
      if @config[:nginx][:use_nginx]
        CloudController::BlobSender::NginxLocalBlobSender.new(missing_blob_handler)
      else
        CloudController::BlobSender::DefaultLocalBlobSender.new(missing_blob_handler)
      end
    end

    private

    def create_paginated_collection_renderer(opts={})
      eager_loader               = opts[:eager_loader] || VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer                 = opts[:serializer] || VCAP::CloudController::RestController::PreloadedObjectSerializer.new
      max_results_per_page       = opts[:max_results_per_page] || @config[:renderer][:max_results_per_page]
      default_results_per_page   = opts[:default_results_per_page] || @config[:renderer][:default_results_per_page]
      max_inline_relations_depth = opts[:max_inline_relations_depth] || @config[:renderer][:max_inline_relations_depth]

      VCAP::CloudController::RestController::PaginatedCollectionRenderer.new(eager_loader, serializer, {
        max_results_per_page:       max_results_per_page,
        default_results_per_page:   default_results_per_page,
        max_inline_relations_depth: max_inline_relations_depth,
      })
    end
  end
end
