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

    def dea_apps_hm9k
      # query 1
      # get all process information where the process is STARTED and running on the DEA
      process_query = App.db["Select p.id, p.app_guid, p.instances, p.version, apps.droplet_guid from processes p
                      inner join apps ON (apps.guid = p.app_guid AND p.state ='STARTED' AND p.diego IS FALSE)"]
      processes = process_query.all

      # query 2
      # get all necessary droplet information. This includes:
      #    where the droplet's associated process is running on the DEA and the process is STARTED
      #    Finding only the latest droplet associated with the process
      droplets_query = App.db["select d.id, d.guid, d.app_guid, d.created_at, d.package_guid, d.state from droplets d
                              join processes p ON (d.app_guid = p.app_guid AND p.state ='STARTED' AND p.diego IS FALSE)
                              inner join (select app_guid, max(created_at) as _max from droplets group by app_guid) as x
                              ON d.app_guid = x.app_guid and d.created_at=x._max"]
      latest_droplets = latest(droplets_query.all)

      # query 3
      # get all necessary package information. This includes:
      #   where the package's associated process is running on the DEA and the process is STARTED
      #   finding only the latest package associated with the process
      packages_query = App.db["select pkg.id, pkg.guid, pkg.app_guid, pkg.created_at, pkg.state from packages pkg
                              join processes proc ON
                                (pkg.app_guid = proc.app_guid AND proc.state ='STARTED' AND proc.diego IS FALSE)
                              inner join (select app_guid, max(created_at) as _max from packages group by app_guid) as x
                              ON pkg.app_guid = x.app_guid and pkg.created_at = x._max"]
      latest_packages = latest(packages_query.all)

      process_list = []
      largest_id = 0

      processes.each do |process|
        app_guid = process[:app_guid]

        pkg_state = package_state(app_guid, process[:droplet_guid], latest_droplets[app_guid], latest_packages[app_guid])
        next if pkg_state == 'FAILED'

        if process[:id] > largest_id
          largest_id = process[:id]
        end

        process_list.push({
          'id'            => app_guid,
          'instances'     => process[:instances],
          'state'         => 'STARTED',
          'version'       => process[:version],
          'package_state' => pkg_state,
        })
      end

      [process_list, largest_id]
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
