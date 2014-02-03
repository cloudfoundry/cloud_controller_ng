require 'new_relic/agent/method_tracer'
require 'cloud_controller/stager/stager_pool'

module CCInitializers
  def self.new_relic_stager_pool_instrumentation(_)
    VCAP::CloudController::StagerPool.class_eval do
      include ::NewRelic::Agent::MethodTracer

      %w(
        find_stager
      ).each do |method_name|
        add_method_tracer(method_name)
      end
    end
  end
end
