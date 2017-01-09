module VCAP::CloudController
  module Dea
    class InstancesReporter
      attr_reader :health_manager_client

      def initialize(health_manager_client)
        @health_manager_client = health_manager_client
      end

      def all_instances_for_app(app)
        VCAP::CloudController::Dea::Client.find_all_instances(app)
      end

      def number_of_starting_and_running_instances_for_process(app)
        return 0 unless app.started?
        return 0 if app.current_droplet.nil?
        health_manager_client.healthy_instances(app)
      end

      def number_of_starting_and_running_instances_for_processes(processes)
        return [] if processes.empty?

        processes_with_running_instances = App.select_all(App.table_name).
                                           runnable.
                                           dea.
                                           where(space: processes.first.space).all

        processes_without_running_instances = processes - processes_with_running_instances
        processes_without_running_instances.inject(
          healthy_instances_bulk(processes_with_running_instances)
        ) do |result, process|
          result.update(process.guid => 0)
        end
      end

      def crashed_instances_for_app(app)
        health_manager_client.find_crashes(app)
      end

      def stats_for_app(app)
        VCAP::CloudController::Dea::Client.find_stats(app)
      end

      private

      def healthy_instances_bulk(apps)
        return {} if apps.empty?
        health_manager_client.healthy_instances_bulk(apps)
      end
    end
  end
end
