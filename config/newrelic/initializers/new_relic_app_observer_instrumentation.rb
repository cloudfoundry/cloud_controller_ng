require 'new_relic/agent/method_tracer'
require 'cloud_controller/app_observer'

module CCInitializers
  def self.new_relic_app_observer_instrumentation(_)
    VCAP::CloudController::AppObserver.class_eval do
      include ::NewRelic::Agent::MethodTracer

      class << self
        %w(
          deleted
          updated
        ).each do |method_name|
          add_method_tracer(
            method_name,
            "Custom/VCAP::CloudController::AppObserver/#{method_name}",
            push_scope: true,
            metric: true,
          )
        end
      end
    end
  end
end
