require 'cloud_controller/dea/runner'
require 'cloud_controller/diego/runner'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/traditional/protocol'
require 'cloud_controller/diego/docker/protocol'
require 'cloud_controller/diego/common/protocol'

module VCAP::CloudController
  class Runners
    def initialize(config, message_bus, dea_pool, stager_pool)
      @config = config
      @message_bus = message_bus
      @dea_pool = dea_pool
      @stager_pool = stager_pool
    end

    def runner_for_app(app)
      app.diego? ? diego_runner(app) : dea_runner(app)
    end

    def run_with_diego?(app)
      app.diego?
    end

    def diego_apps(batch_size, last_id)
      App.
        eager(:current_saved_droplet, :space, :stack, :service_bindings, { routes: :domain }).
        where('apps.id > ?', last_id).
        where('deleted_at IS NULL').
        where(state: 'STARTED').
        where(package_state: 'STAGED').
        where(diego: true).
        order(:id).
        limit(batch_size).
        all
    end

    def diego_apps_from_process_guids(process_guids)
      process_guids = Array(process_guids).to_set
      App.
        eager(:current_saved_droplet, :space, :stack, :service_bindings, { routes: :domain }).
        where(guid: process_guids.map { |pg| Diego::ProcessGuid.app_guid(pg) }).
        where('deleted_at IS NULL').
        where(state: 'STARTED').
        where(package_state: 'STAGED').
        where(diego: true).
        order(:id).
        all.
        select { |app| process_guids.include?(Diego::ProcessGuid.from_app(app)) }
    end

    def diego_apps_cache_data(batch_size, last_id)
      App.select(:id, :guid, :version, :updated_at).
        where('id > ?', last_id).
        where(state: 'STARTED').
        where(package_state: 'STAGED').
        where('deleted_at IS NULL').
        where(diego: true).
        order(:id).
        limit(batch_size).
        select_map([:id, :guid, :version, :updated_at])
    end

    def dea_apps(batch_size, last_id)
      query = App.
        where('id > ?', last_id).
        where('deleted_at IS NULL').
        order(:id).
        where(diego: false).
        limit(batch_size)

      query.all
    end

    private

    def diego_runner(app)
      app.docker_image.present? ? diego_docker_runner(app) : diego_traditional_runner(app)
    end

    def dea_runner(app)
      Dea::Runner.new(app, @config, @message_bus, @dea_pool, @stager_pool)
    end

    def diego_docker_runner(app)
      dependency_locator = CloudController::DependencyLocator.instance
      nsync_client = dependency_locator.nsync_client
      stager_client = dependency_locator.stager_client
      protocol = Diego::Docker::Protocol.new(Diego::Common::Protocol.new)
      messenger = Diego::Messenger.new(stager_client, nsync_client, protocol)
      Diego::Runner.new(app, messenger, protocol, @config[:default_health_check_timeout])
    end

    def diego_traditional_runner(app)
      dependency_locator = CloudController::DependencyLocator.instance
      nsync_client = dependency_locator.nsync_client
      stager_client = dependency_locator.stager_client
      protocol = Diego::Traditional::Protocol.new(dependency_locator.blobstore_url_generator(true), Diego::Common::Protocol.new)
      messenger = Diego::Messenger.new(stager_client, nsync_client, protocol)
      Diego::Runner.new(app, messenger, protocol, @config[:default_health_check_timeout])
    end

    def staging_timeout
      @config[:staging][:timeout_in_seconds]
    end
  end
end
