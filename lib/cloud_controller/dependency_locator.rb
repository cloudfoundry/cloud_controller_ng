require 'repositories/app_event_repository'
require 'repositories/build_event_repository'
require 'repositories/space_event_repository'
require 'repositories/organization_event_repository'
require 'repositories/route_event_repository'
require 'repositories/user_event_repository'
require 'cloud_controller/rest_controller/object_renderer'
require 'cloud_controller/rest_controller/paginated_collection_renderer'
require 'cloud_controller/upload_handler'
require 'cloud_controller/blob_sender/nginx_blob_sender'
require 'cloud_controller/blob_sender/default_blob_sender'
require 'cloud_controller/blob_sender/missing_blob_handler'
require 'traffic_controller/client'
require 'cloud_controller/diego/task_recipe_builder'
require 'cloud_controller/diego/app_recipe_builder'
require 'cloud_controller/diego/stager_client'
require 'cloud_controller/diego/bbs_apps_client'
require 'cloud_controller/diego/bbs_stager_client'
require 'cloud_controller/diego/bbs_task_client'
require 'cloud_controller/diego/bbs_instances_client'
require 'cloud_controller/diego/tps_client'
require 'cloud_controller/diego/messenger'
require 'cloud_controller/blobstore/client_provider'
require 'cloud_controller/resource_pool_wrapper'
require 'cloud_controller/bits_service_resource_pool_wrapper'
require 'cloud_controller/packager/local_bits_packer'
require 'cloud_controller/packager/bits_service_packer'

require 'bits_service_client'

module CloudController
  class DependencyLocator
    include Singleton
    include VCAP::CloudController

    LARGE_COLLECTION_SIZE = 10_000
    BUILDPACK_CACHE_DIR = 'buildpack_cache'.freeze
    RESOURCE_POOL_DIR = 'app_bits_cache'.freeze

    attr_accessor :config

    def initialize
      @config = VCAP::CloudController::Config.config
      @dependencies = {}
    end

    def config
      @config || raise('config not set')
    end

    def reset(config)
      @config = config
      @dependencies = {}
    end

    def register(name, value)
      @dependencies[name] = value
    end

    def runners
      @dependencies[:runners] || register(:runners, VCAP::CloudController::Runners.new(config))
    end

    def stagers
      @dependencies[:stagers] || register(:stagers, VCAP::CloudController::Stagers.new(config))
    end

    def nsync_client
      @dependencies[:nsync_client] || register(:nsync_client, VCAP::CloudController::Diego::NsyncClient.new(config))
    end

    def stager_client
      @dependencies[:stager_client] || register(:stager_client, VCAP::CloudController::Diego::StagerClient.new(config))
    end

    def bbs_apps_client
      @dependencies[:bbs_apps_client] || register(:bbs_apps_client, build_bbs_apps_client)
    end

    def bbs_stager_client
      @dependencies[:bbs_stager_client] || register(:bbs_stager_client, build_bbs_stager_client)
    end

    def bbs_task_client
      @dependencies[:bbs_task_client] || register(:bbs_task_client, build_bbs_task_client)
    end

    def bbs_instances_client
      @dependencies[:bbs_instances_client] || register(:bbs_instances_client, build_bbs_instances_client)
    end

    def tps_client
      @dependencies[:tps_client] || register(:tps_client, Diego::TPSClient.new(config))
    end

    def traffic_controller_client
      @dependencies[:traffic_controller_client] || register(:traffic_controller_client, build_traffic_controller_client)
    end

    def upload_handler
      @dependencies[:upload_handler] || register(:upload_handler, UploadHandler.new(config))
    end

    def app_event_repository
      @dependencies[:app_event_repository] || register(:app_event_repository, Repositories::AppEventRepository.new)
    end

    def instances_reporters
      @dependencies[:instances_reporters] || register(:instances_reporters, InstancesReporters.new)
    end

    def index_stopper
      @dependencies[:index_stopper] || register(:index_stopper, IndexStopper.new(runners))
    end

    def droplet_blobstore
      options = config.get(:droplets)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:droplet_directory_key),
        resource_type: :droplets,
      )
    end

    def buildpack_cache_blobstore
      options = config.get(:droplets)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:droplet_directory_key),
        root_dir: BUILDPACK_CACHE_DIR,
        resource_type: :buildpack_cache,
      )
    end

    def package_blobstore
      options = config.get(:packages)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:app_package_directory_key),
        resource_type: :packages,
      )
    end

    def legacy_global_app_bits_cache
      options = config.get(:resource_pool)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:resource_directory_key),
      )
    end

    def global_app_bits_cache
      options = config.get(:resource_pool)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:resource_directory_key),
        root_dir: RESOURCE_POOL_DIR,
      )
    end

    def buildpack_blobstore
      options = config.get(:buildpacks)

      Blobstore::ClientProvider.provide(
        options: options,
        directory_key: options.fetch(:buildpack_directory_key, 'cc-buildpacks'),
        resource_type: :buildpacks,
      )
    end

    def blobstore_url_generator
      connection_options = {
        blobstore_host: config.get(:internal_service_hostname),
        blobstore_external_port: config.get(:external_port),
        blobstore_tls_port: config.get(:tls_port),
        user: config.get(:staging, :auth, :user),
        password: config.get(:staging, :auth, :password),
        mtls: config.get(:diego, :temporary_cc_uploader_mtls),
      }

      Blobstore::UrlGenerator.new(
        connection_options,
        package_blobstore,
        buildpack_cache_blobstore,
        buildpack_blobstore,
        droplet_blobstore,
      )
    end

    def droplet_url_generator
      VCAP::CloudController::Diego::Buildpack::DropletUrlGenerator.new(
        internal_service_hostname: config.get(:internal_service_hostname),
        external_port: config.get(:external_port),
        tls_port: config.get(:tls_port),
        mtls: config.get(:diego, :temporary_droplet_download_mtls),
      )
    end

    def space_event_repository
      Repositories::SpaceEventRepository.new
    end

    def organization_event_repository
      Repositories::OrganizationEventRepository.new
    end

    def user_event_repository
      Repositories::UserEventRepository.new
    end

    def route_event_repository
      Repositories::RouteEventRepository.new
    end

    def services_event_repository
      Repositories::ServiceEventRepository.new(UserAuditInfo.from_context(SecurityContext))
    end

    def service_manager
      VCAP::Services::ServiceBrokers::ServiceManager.new(services_event_repository)
    end

    def app_repository
      AppRepository.new
    end

    def object_renderer
      create_object_renderer
    end

    def username_populating_object_renderer
      create_object_renderer(object_transformer: UsernamePopulator.new(uaa_client))
    end

    def paginated_collection_renderer
      create_paginated_collection_renderer
    end

    def large_paginated_collection_renderer
      create_paginated_collection_renderer(max_results_per_page: LARGE_COLLECTION_SIZE)
    end

    def username_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: UsernamePopulator.new(uaa_client))
    end

    def username_and_roles_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: UsernamesAndRolesPopulator.new(uaa_client))
    end

    def router_group_type_populating_collection_renderer
      create_paginated_collection_renderer(collection_transformer: RouterGroupTypePopulator.new(routing_api_client))
    end

    def uaa_client
      UaaClient.new(
        uaa_target: config.get(:uaa, :internal_url),
        client_id: config.get(:cloud_controller_username_lookup_client_name),
        secret: config.get(:cloud_controller_username_lookup_client_secret),
        ca_file: config.get(:uaa, :ca_file),
      )
    end

    def routing_api_client
      return RoutingApi::DisabledClient.new if config.get(:routing_api).nil?

      uaa_client = UaaClient.new(
        uaa_target: config.get(:uaa, :internal_url),
        client_id: config.get(:routing_api, :routing_client_name),
        secret: config.get(:routing_api, :routing_client_secret),
        ca_file: config.get(:uaa, :ca_file),
      )

      skip_cert_verify = config.get(:skip_cert_verify)
      routing_api_url = config.get(:routing_api, :url)
      RoutingApi::Client.new(routing_api_url, uaa_client, skip_cert_verify)
    end

    def missing_blob_handler
      CloudController::BlobSender::MissingBlobHandler.new
    end

    def blob_sender
      if config.get(:nginx, :use_nginx)
        CloudController::BlobSender::NginxLocalBlobSender.new
      else
        CloudController::BlobSender::DefaultLocalBlobSender.new
      end
    end

    def bits_service_resource_pool
      return nil unless use_bits_service

      BitsService::ResourcePool.new(
        endpoint: bits_service_options[:private_endpoint],
        request_timeout_in_seconds: config.get(:request_timeout_in_seconds),
      )
    end

    def resource_pool_wrapper
      if bits_service_resource_pool
        BitsServiceResourcePoolWrapper
      else
        ResourcePoolWrapper
      end
    end

    def bits_service_options
      config.get(:bits_service)
    end

    def use_bits_service
      bits_service_options[:enabled]
    end

    def packer
      if use_bits_service
        Packager::BitsServicePacker.new
      else
        Packager::LocalBitsPacker.new
      end
    end

    private

    def build_bbs_stager_client
      bbs_client = ::Diego::Client.new(
        url: config.get(:diego, :bbs, :url),
        ca_cert_file: config.get(:diego, :bbs, :ca_file),
        client_cert_file: config.get(:diego, :bbs, :cert_file),
        client_key_file: config.get(:diego, :bbs, :key_file),
      )

      VCAP::CloudController::Diego::BbsStagerClient.new(bbs_client)
    end

    def build_bbs_apps_client
      bbs_client = ::Diego::Client.new(
        url: config.get(:diego, :bbs, :url),
        ca_cert_file: config.get(:diego, :bbs, :ca_file),
        client_cert_file: config.get(:diego, :bbs, :cert_file),
        client_key_file: config.get(:diego, :bbs, :key_file),
      )

      VCAP::CloudController::Diego::BbsAppsClient.new(bbs_client)
    end

    def build_bbs_task_client
      bbs_client = ::Diego::Client.new(
        url: config.get(:diego, :bbs, :url),
        ca_cert_file: config.get(:diego, :bbs, :ca_file),
        client_cert_file: config.get(:diego, :bbs, :cert_file),
        client_key_file: config.get(:diego, :bbs, :key_file)
      )

      VCAP::CloudController::Diego::BbsTaskClient.new(bbs_client)
    end

    def build_bbs_instances_client
      bbs_client = ::Diego::Client.new(
        url: config.get(:diego, :bbs, :url),
        ca_cert_file: config.get(:diego, :bbs, :ca_file),
        client_cert_file: config.get(:diego, :bbs, :cert_file),
        client_key_file: config.get(:diego, :bbs, :key_file),
      )

      VCAP::CloudController::Diego::BbsInstancesClient.new(bbs_client)
    end

    def build_traffic_controller_client
      TrafficController::Client.new(url: config.get(:loggregator, :internal_url))
    end

    def create_object_renderer(opts={})
      eager_loader = VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer = VCAP::CloudController::RestController::PreloadedObjectSerializer.new
      object_transformer = opts[:object_transformer]

      VCAP::CloudController::RestController::ObjectRenderer.new(eager_loader, serializer, {
        max_inline_relations_depth: config.get(:renderer, :max_inline_relations_depth),
        object_transformer: object_transformer,
      })
    end

    def create_paginated_collection_renderer(opts={})
      eager_loader = opts[:eager_loader] || VCAP::CloudController::RestController::SecureEagerLoader.new
      serializer = opts[:serializer] || VCAP::CloudController::RestController::PreloadedObjectSerializer.new
      max_results_per_page = opts[:max_results_per_page] || config.get(:renderer, :max_results_per_page)
      default_results_per_page = opts[:default_results_per_page] || config.get(:renderer, :default_results_per_page)
      max_inline_relations_depth = opts[:max_inline_relations_depth] || config.get(:renderer, :max_inline_relations_depth)
      collection_transformer = opts[:collection_transformer]

      VCAP::CloudController::RestController::PaginatedCollectionRenderer.new(eager_loader, serializer, {
        max_results_per_page: max_results_per_page,
        default_results_per_page: default_results_per_page,
        max_inline_relations_depth: max_inline_relations_depth,
        collection_transformer: collection_transformer
      })
    end
  end
end
