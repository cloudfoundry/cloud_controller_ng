require 'new_relic/agent/method_tracer'
require 'cloud_controller/dea/hm9000/client'

module CCInitializers
  def self.new_relic_hm9000_client_instrumentation(_)
    VCAP::CloudController::Dea::HM9000::Client.class_eval do
      include ::NewRelic::Agent::MethodTracer

      %w(
        healthy_instances
        healthy_instances_bulk
        find_crashes
        find_flapping_indices
      ).each do |method_name|
        add_method_tracer(method_name)
      end
    end
  end
end
