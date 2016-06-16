require 'cloud_controller/dea/runner'
require 'cloud_controller/diego/runner'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/protocol'
require 'cloud_controller/diego/buildpack/lifecycle_protocol'
require 'cloud_controller/diego/docker/lifecycle_protocol'
require 'cloud_controller/diego/egress_rules'

module VCAP::CloudController
  class Runners
    def initialize(config, message_bus, dea_pool)
      @config = config
      @message_bus = message_bus
      @dea_pool = dea_pool
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
        select { |app| process_guids.include?(Diego::ProcessGuid.from_process(app)) }
    end

    def diego_apps_cache_data(batch_size, last_id)
      diego_apps = App.select(:id, :guid, :version, :updated_at).
                   where('id > ?', last_id).
                   where(state: 'STARTED').
                   where(package_state: 'STAGED').
                   where('deleted_at IS NULL').
                   where(diego: true)
      diego_apps = filter_docker_apps(diego_apps) unless FeatureFlag.enabled?(:diego_docker)
      diego_apps.order(:id).
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

    EXPORT_ATTRIBUTES = [
      :instances,
      :state,
      :memory,
      :package_state,
      :version
    ].freeze

    def dea_apps_hm9k(batch_size, last_id)
      query = App.
              where('id > ?', last_id).
              where('deleted_at IS NULL').
              order(:id).
              where(diego: false).
              where(state: 'STARTED').
              exclude(package_state: 'FAILED').
              limit(batch_size).
              select_map([:id, :guid, :instances, :state, :memory, :package_state, :version, :created_at, :updated_at])

      app_hashes = query.map do |row|
        hash = {}
        EXPORT_ATTRIBUTES.each_with_index { |obj, i| hash[obj.to_s] = row[i + 2] }

        hash['id'] = row[1]
        hash['updated_at'] = row[8] || row[7]
        hash
      end

      id_for_next_token = app_hashes.empty? ? nil : query.last[0]
      [app_hashes, id_for_next_token]
    end

    private

    def diego_runner(app)
      Diego::Runner.new(app, @config[:default_health_check_timeout])
    end

    def dea_runner(app)
      Dea::Runner.new(app, @config, dependency_locator.blobstore_url_generator, @message_bus, @dea_pool)
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end

    def staging_timeout
      @config[:staging][:timeout_in_seconds]
    end

    def filter_docker_apps(query)
      query.where(docker_image: nil)
    end
  end
end
