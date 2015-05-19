require 'repositories/runtime/app_event_repository'
require 'repositories/runtime/space_event_repository'
require 'cloud_controller/rest_controller/object_renderer'
require 'cloud_controller/rest_controller/paginated_collection_renderer'
require 'cloud_controller/upload_handler'
require 'cloud_controller/blob_sender/ngx_blob_sender'
require 'cloud_controller/blob_sender/default_blob_sender'
require 'cloud_controller/blob_sender/missing_blob_handler'
require 'cloud_controller/diego/stager_client'
require 'cloud_controller/diego/tps_client'
require 'cloud_controller/diego/messenger'
require 'cloud_controller/diego/traditional/protocol'

module CloudController
  class DependencyLocator
    include Singleton
    include VCAP::CloudController

    LARGE_COLLECTION_SIZE = 10_000

    attr_accessor :config

    def initialize
      @config = VCAP::CloudController::Config.config
      @dependencies = {}
    end

    def config
      @config || raise('config not set')
    end

    def register(name, value)
      @dependencies[name] = value
    end

    def health_manager_client
      @dependencies[:health_manager_client] || raise('health_manager_client not set')
    end

    def runners
      @dependencies[:runners] || raise('runners not set')
    end

    def stagers
      @dependencies[:stagers] || raise('stagers not set')
    end

    def nsync_client
      @dependencies[:nsync_client] || raise('nsync_client not set')
    end

    def stager_client
      @dependencies[:stager_client] || raise('stager_client not set')
    end

    def tps_client
      @dependencies[:tps_client] || raise('tps_client not set')
    end

    def upload_handler
      @dependencies[:upload_handler] || raise('upload_handler not set')
    end

    def app_event_repository
      @dependencies[:app_event_repository] || raise('app_event_repository not set')
    end

    def instances_reporters
      @dependencies[:instances_reporters] || raise('instances_reporters not set')
    end

    def index_stopper
      @dependencies[:index_stopper] || raise('index_stopper not set')
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
        'buildpack_cache'
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
        @config[:buildpacks][:buildpack_directory_key] || 'cc-buildpacks'
      )
    end

    def blobstore_url_generator(use_service_dns=false)
      hostname = use_service_dns && @config[:internal_service_hostname] || @config[:external_host]

      connection_options = {
        blobstore_host: hostname,
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

    def services_event_repository
      Repositories::Services::EventRepository.new(
        user: SecurityContext.current_user,
        user_email: SecurityContext.current_user_email
      )
    end

    def service_manager
      VCAP::Services::ServiceBrokers::ServiceManager.new(services_event_repository)
    end

    def app_repository
      AppRepository.new
    end

    def process_presenter
      ProcessPresenter.new
    end

    def app_presenter
      AppPresenter.new
    end

    def package_presenter
      PackagePresenter.new
    end

    def droplet_presenter
      DropletPresenter.new
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

    def username_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: UsernamePopulator.new(username_lookup_uaa_client))
    end

    def username_and_roles_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: UsernamesAndRolesPopulator.new(username_lookup_uaa_client))
    end

    def quota_usage_populating_renderer
      create_object_renderer(transformer: QuotaUsagePopulator.new)
    end

    def username_lookup_uaa_client
      client_id = @config[:cloud_controller_username_lookup_client_name]
      secret = @config[:cloud_controller_username_lookup_client_secret]
      target = @config[:uaa][:url]
      skip_cert_verify = @config[:skip_cert_verify]
      UaaClient.new(target, client_id, secret, { skip_ssl_validation: skip_cert_verify })
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

    def create_object_renderer(opts={})
      eager_loader               = opts[:eager_loader] || VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer                 = opts[:serializer] || VCAP::CloudController::RestController::PreloadedObjectSerializer.new
      max_inline_relations_depth = opts[:max_inline_relations_depth] || @config[:renderer][:max_inline_relations_depth]
      transformer     = opts[:transformer]

      VCAP::CloudController::RestController::ObjectRenderer.new(eager_loader, serializer, {
        max_inline_relations_depth: max_inline_relations_depth,
        transformer: transformer
      })
    end

    def create_paginated_collection_renderer(opts={})
      eager_loader               = opts[:eager_loader] || VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer                 = opts[:serializer] || VCAP::CloudController::RestController::PreloadedObjectSerializer.new
      max_results_per_page       = opts[:max_results_per_page] || @config[:renderer][:max_results_per_page]
      default_results_per_page   = opts[:default_results_per_page] || @config[:renderer][:default_results_per_page]
      max_inline_relations_depth = opts[:max_inline_relations_depth] || @config[:renderer][:max_inline_relations_depth]
      collection_transformer     = opts[:collection_transformer]

      VCAP::CloudController::RestController::PaginatedCollectionRenderer.new(eager_loader, serializer, {
        max_results_per_page:       max_results_per_page,
        default_results_per_page:   default_results_per_page,
        max_inline_relations_depth: max_inline_relations_depth,
        collection_transformer: collection_transformer
      })
    end
  end
end
