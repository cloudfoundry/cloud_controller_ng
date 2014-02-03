require 'new_relic/agent/method_tracer'
require 'cloud_controller/hm9000_client'

module CCInitializers
  def self.new_relic_hm9000_client_instrumentation(_)
    VCAP::CloudController::HM9000Client.class_eval do
      include ::NewRelic::Agent::MethodTracer

      %w(
        healthy_instances
        find_crashes
        find_flapping_indices
      ).each do |method_name|
        add_method_tracer(method_name)
      end
    end
  end
end
