require 'repositories/app_event_repository'
require 'repositories/space_event_repository'
require 'repositories/route_event_repository'
require 'cloud_controller/rest_controller/object_renderer'
require 'cloud_controller/rest_controller/paginated_collection_renderer'
require 'cloud_controller/upload_handler'
require 'cloud_controller/blob_sender/nginx_blob_sender'
require 'cloud_controller/blob_sender/default_blob_sender'
require 'cloud_controller/blob_sender/missing_blob_handler'
require 'cloud_controller/diego/stager_client'
require 'cloud_controller/diego/tps_client'
require 'cloud_controller/diego/messenger'
require 'cloud_controller/blobstore/client_provider'
require 'cloud_controller/resource_pool_wrapper'
require 'cloud_controller/bits_service_resource_pool_wrapper'

require 'bits_service_client'

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
      options = @config.fetch(:droplets)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:droplet_directory_key),
        resource_type: :droplets
      )
    end

    def buildpack_cache_blobstore
      options = @config.fetch(:droplets)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:droplet_directory_key),
        root_dir: 'buildpack_cache',
        resource_type: :buildpack_cache
      )
    end

    def package_blobstore
      options = @config.fetch(:packages)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:app_package_directory_key),
        resource_type: :packages
      )
    end

    def global_app_bits_cache
      options = @config.fetch(:resource_pool)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:resource_directory_key)
      )
    end

    def buildpack_blobstore
      options = @config.fetch(:buildpacks)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:buildpack_directory_key, 'cc-buildpacks'),
        resource_type: :buildpacks
      )
    end

    def blobstore_url_generator
      connection_options = {
        blobstore_host: @config[:internal_service_hostname],
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
      Repositories::SpaceEventRepository.new
    end

    def route_event_repository
      Repositories::RouteEventRepository.new
    end

    def services_event_repository
      Repositories::ServiceEventRepository.new(
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

    def username_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: UsernamePopulator.new(username_lookup_uaa_client))
    end

    def username_and_roles_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: UsernamesAndRolesPopulator.new(username_lookup_uaa_client))
    end

    def router_group_type_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: RouterGroupTypePopulator.new(routing_api_client))
    end

    def username_lookup_uaa_client
      client_id = @config[:cloud_controller_username_lookup_client_name]
      secret = @config[:cloud_controller_username_lookup_client_secret]
      target = @config[:uaa][:url]
      skip_cert_verify = @config[:skip_cert_verify]
      UaaClient.new(target, client_id, secret, { skip_ssl_validation: skip_cert_verify })
    end

    def routing_api_client
      return RoutingApi::DisabledClient.new if @config[:routing_api].nil?
      skip_cert_verify = @config[:skip_cert_verify]

      client_id = @config[:routing_api] && @config[:routing_api][:routing_client_name]
      secret = @config[:routing_api] && @config[:routing_api][:routing_client_secret]
      uaa_target = @config[:uaa][:url]
      token_issuer = CF::UAA::TokenIssuer.new(uaa_target, client_id, secret, { skip_ssl_validation: skip_cert_verify })

      routing_api_url = @config[:routing_api] && @config[:routing_api][:url]
      RoutingApi::Client.new(routing_api_url, token_issuer, skip_cert_verify)
    end

    def missing_blob_handler
      CloudController::BlobSender::MissingBlobHandler.new
    end

    def blob_sender
      if @config[:nginx][:use_nginx]
        CloudController::BlobSender::NginxLocalBlobSender.new
      else
        CloudController::BlobSender::DefaultLocalBlobSender.new
      end
    end

    def bits_service_resource_pool
      return nil unless use_bits_service
      BitsService::ResourcePool.new(endpoint: bits_service_options[:private_endpoint])
    end

    def resource_pool_wrapper
      if bits_service_resource_pool
        BitsServiceResourcePoolWrapper
      else
        ResourcePoolWrapper
      end
    end

    def bits_service_options
      @config[:bits_service]
    end

    def use_bits_service
      bits_service_options[:enabled]
    end

    def packer_class
      if use_bits_service
        Jobs::Runtime::BitsServicePacker
      else
        Jobs::Runtime::AppBitsPacker
      end
    end

    private

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
