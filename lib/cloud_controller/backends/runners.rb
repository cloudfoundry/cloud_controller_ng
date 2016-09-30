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
      App.select_all(App.table_name).
        diego.
        runnable.
        where("#{App.table_name}.id > ?", last_id).
        order("#{App.table_name}__id".to_sym).
        limit(batch_size).
        eager(:current_droplet, :space, :service_bindings, { routes: :domain }, { app: :buildpack_lifecycle_data }).
        all
    end

    def diego_apps_from_process_guids(process_guids)
      process_guids = Array(process_guids).to_set
      App.select_all(App.table_name).
        diego.
        runnable.
        where("#{App.table_name}__guid".to_sym => process_guids.map { |pg| Diego::ProcessGuid.app_guid(pg) }).
        order("#{App.table_name}__id".to_sym).
        eager(:current_droplet, :space, :service_bindings, { routes: :domain }, { app: :buildpack_lifecycle_data }).
        all.
        select { |app| process_guids.include?(Diego::ProcessGuid.from_process(app)) }
    end

    def diego_apps_cache_data(batch_size, last_id)
      diego_apps = App.
                   diego.
                   runnable.
                   where("#{App.table_name}.id > ?", last_id).
                   order("#{App.table_name}__id".to_sym).
                   limit(batch_size)

      diego_apps = diego_apps.buildpack_type unless FeatureFlag.enabled?(:diego_docker)

      diego_apps.select_map([
        "#{App.table_name}__id".to_sym,
        "#{App.table_name}__guid".to_sym,
        "#{App.table_name}__version".to_sym,
        "#{App.table_name}__updated_at".to_sym
      ])
    end

    def dea_apps(batch_size, last_id)
      query = App.select_all(App.table_name).
              dea.
              where("#{App.table_name}.id > ?", last_id).
              order("#{App.table_name}__id".to_sym).
              limit(batch_size)

      query.all
    end

    def dea_apps_hm9k(batch_size, last_id)
      query = App.select_all(App.table_name).
              runnable.
              dea.
              where("#{App.table_name}.id > ?", last_id).
              order("#{App.table_name}__id".to_sym).
              limit(batch_size).
              eager(:latest_droplet, :latest_package, current_droplet: :package)

      apps = query.all.reject { |a| a.package_state == 'FAILED' }

      app_hashes = apps.map do |app|
        {
          'id'            => app.guid,
          'instances'     => app.instances,
          'state'         => app.state,
          'memory'        => app.memory,
          'version'       => app.version,
          'updated_at'    => app.updated_at || app.created_at,
          'package_state' => app.package_state,
        }
      end

      id_for_next_token = apps.empty? ? nil : apps.last.id
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
  end
end
