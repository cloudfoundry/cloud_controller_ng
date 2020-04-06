require 'cloud_controller/diego'
require 'cloud_controller/diego/runner'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/buildpack/lifecycle_protocol'
require 'cloud_controller/diego/docker/lifecycle_protocol'
require 'cloud_controller/diego/egress_rules'
require 'cloud_controller/backends/copilot_runner_delegator'

module VCAP::CloudController
  class Runners
    def initialize(config)
      @config = config
    end

    def runner_for_process(process)
      # TODO: stop using this Copilot wrapper since no more Copilot
      # see: https://github.com/cloudfoundry/istio-release#deprecated
      CopilotRunnerDelegator.new(diego_runner(process), process)
    end

    def diego_processes(batch_size, last_id)
      ProcessModel.select_all(ProcessModel.table_name).
        diego.
        runnable.
        where(Sequel.lit("#{ProcessModel.table_name}.id > ?", last_id)).
        order("#{ProcessModel.table_name}__id".to_sym).
        limit(batch_size).
        eager(:desired_droplet, :space, :service_bindings, { routes: :domain }, { app: :buildpack_lifecycle_data }).
        all
    end

    def processes_from_diego_process_guids(diego_process_guids)
      diego_process_guids = Array(diego_process_guids).to_set
      ProcessModel.select_all(ProcessModel.table_name).
        diego.
        runnable.
        where("#{ProcessModel.table_name}__guid".to_sym => diego_process_guids.map { |pg| Diego::ProcessGuid.cc_process_guid(pg) }).
        order("#{ProcessModel.table_name}__id".to_sym).
        eager(:desired_droplet, :space, :service_bindings, { routes: :domain }, { app: :buildpack_lifecycle_data }).
        all.
        select { |process| diego_process_guids.include?(Diego::ProcessGuid.from_process(process)) }
    end

    def diego_apps_cache_data(batch_size, last_id)
      diego_apps = ProcessModel.
                   diego.
                   runnable.
                   where(Sequel.lit("#{ProcessModel.table_name}.id > ?", last_id)).
                   order("#{ProcessModel.table_name}__id".to_sym).
                   limit(batch_size)

      diego_apps = diego_apps.buildpack_type unless FeatureFlag.enabled?(:diego_docker)

      diego_apps.select_map([
        "#{ProcessModel.table_name}__id".to_sym,
        "#{ProcessModel.table_name}__guid".to_sym,
        "#{ProcessModel.table_name}__version".to_sym,
        "#{ProcessModel.table_name}__updated_at".to_sym
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

    private

    def diego_runner(process)
      Diego::Runner.new(process, @config)
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end

    def staging_timeout
      @config.get(:staging, :timeout_in_seconds)
    end
  end
end
