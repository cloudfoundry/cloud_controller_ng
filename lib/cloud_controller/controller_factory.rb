module CloudController
  class ControllerFactory
    # rubocop:disable CyclomaticComplexity
    include VCAP::CloudController

    def initialize(config, logger, env, params, body, sinatra = nil)
      @config  = config
      @logger  = logger
      @env     = env
      @params  = params
      @body    = body
      @sinatra = sinatra
    end

    def create_controller(klass)
      dependencies = dependencies_for_class(klass)
      klass.new(@config, @logger, @env, @params, @body, @sinatra, dependencies)
    end

    private

    def dependency_locator
      DependencyLocator.instance
    end

    def dependencies_for_class(klass)
      default_dependencies = {
        object_renderer:     dependency_locator.object_renderer,
        collection_renderer: dependency_locator.paginated_collection_renderer,
      }

      custom_dependencies = case klass.name.demodulize
                              when 'BuildpacksController', 'BuildpackBitsController'
                                {
                                  buildpack_blobstore: dependency_locator.buildpack_blobstore,
                                  upload_handler:      dependency_locator.upload_handler,
                                }
                              when 'StagingsController'
                                {
                                  droplet_blobstore:         dependency_locator.droplet_blobstore,
                                  buildpack_cache_blobstore: dependency_locator.buildpack_cache_blobstore,
                                  package_blobstore:         dependency_locator.package_blobstore,
                                  blobstore_url_generator:   dependency_locator.blobstore_url_generator,
                                  missing_blob_handler:      dependency_locator.missing_blob_handler,
                                  blob_sender:               dependency_locator.blob_sender,
                                  config:                    @config,
                                }
                              when 'StagingCompletionController'
                                {
                                  stagers:   dependency_locator.stagers
                                }
                              when 'AppsController', 'RestagesController', 'AppBitsUploadController'
                                { app_event_repository: dependency_locator.app_event_repository }
                              when 'SpacesController'
                                { space_event_repository: dependency_locator.space_event_repository }
                              when 'AppUsageEventsController'
                                {
                                  collection_renderer: dependency_locator.large_paginated_collection_renderer,
                                }
                              when 'BillingEventsController'
                                billing_dependencies
                              when 'InstancesController', 'SpaceSummariesController', 'AppSummariesController',
                                   'CrashesController', 'StatsController'
                                instances_reporters
                              when 'AppBitsDownloadController'
                                app_bits_download_dependencies
                              when 'ProcessesController'
                                process_dependencies
                              when 'AppsV3Controller'
                                app_v3_dependencies
                              when 'ServiceBrokersController'
                                service_brokers_dependencies
                              else
                                {}
                              end

      default_dependencies.merge(custom_dependencies)
    end

    def service_brokers_dependencies
      {
        services_event_repository: dependency_locator.services_event_repository
      }
    end

    def billing_dependencies
      {
        object_renderer:     nil, # no object rendering
        collection_renderer: dependency_locator.entity_only_paginated_collection_renderer,
      }
    end

    def instances_reporters
      { instances_reporters:   dependency_locator.instances_reporters }
    end

    def app_bits_download_dependencies
      {
        blob_sender:          dependency_locator.blob_sender,
        package_blobstore:    dependency_locator.package_blobstore,
        missing_blob_handler: dependency_locator.missing_blob_handler,
      }
    end

    def process_dependencies
      { process_repository: dependency_locator.process_repository }
    end

    def app_v3_dependencies
      {
        app_repository: dependency_locator.app_repository,
        process_repository: dependency_locator.process_repository,
      }
    end
  end
end
