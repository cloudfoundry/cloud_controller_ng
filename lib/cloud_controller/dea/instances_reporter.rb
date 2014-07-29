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

      def number_of_starting_and_running_instances_for_app(app)
        return 0 unless app.started?
        health_manager_client.healthy_instances(app)
      end

      def number_of_starting_and_running_instances_for_apps(apps)
        stopped_apps = apps.select { |app| !app.started? }
        stopped_apps.inject(healthy_instances_bulk(apps - stopped_apps)) do |result, app|
          result.update(app.guid => 0)
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
