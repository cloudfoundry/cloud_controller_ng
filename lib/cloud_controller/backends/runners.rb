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
      diego_runner(app)
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

    def latest(items)
      current = {}

      items.each do |item|
        c = current[item[:app_guid]]
        if c.nil? || (item[:created_at] == c[:created_at] && item[:id] > c[:id])
          current[item[:app_guid]] = item
        end
      end

      current
    end

    def package_state(app_guid, current_droplet_guid, latest_droplet, latest_package)
      if latest_droplet
        return 'FAILED' if latest_droplet[:state] == DropletModel::FAILED_STATE

        # Process of staging
        return 'PENDING' if current_droplet_guid != latest_droplet[:guid]

        if latest_package
          return 'STAGED' if latest_droplet[:package_guid] == latest_package[:guid] || latest_droplet[:created_at] > latest_package[:created_at]
          return 'FAILED' if latest_package[:state] == PackageModel::FAILED_STATE
          return 'PENDING'
        end

        return 'STAGED'
      end

      return 'FAILED' if latest_package && latest_package[:state] == PackageModel::FAILED_STATE

      # At this point you could have no package on an app
      # At this point you have a latest package, but no droplet. So staging has not occured
      'PENDING'
    end

    private

    def diego_runner(app)
      Diego::Runner.new(app, @config)
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end

    def staging_timeout
      @config[:staging][:timeout_in_seconds]
    end
  end
end
