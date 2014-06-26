require 'new_relic/agent/method_tracer'
require 'cloud_controller/dea/dea_client'

module CCInitializers
  def self.new_relic_dea_client_instrumentation(_)
    VCAP::CloudController::DeaClient.class_eval do
      include ::NewRelic::Agent::MethodTracer

      class << self
        %w(
          start
          stop
          find_specific_instance
          find_instances
          find_all_instances
          change_running_instances
          start_instances
          start_instance_at_index
          stop_indices
          stop_instances
          get_file_uri_for_active_instance_by_index
          get_file_uri_by_instance_guid
          update_uris
          find_stats
        ).each do |method_name|
          add_method_tracer(
            method_name,
            "Custom/VCAP::CloudController::DeaClient/#{method_name}",
            push_scope: true,
            metric: true,
          )
        end
      end
    end
  end
end
