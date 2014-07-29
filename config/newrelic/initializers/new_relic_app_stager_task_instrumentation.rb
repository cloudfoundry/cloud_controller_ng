require 'new_relic/agent/method_tracer'
require 'cloud_controller/dea/app_stager_task'

module CCInitializers
  def self.new_relic_app_stager_task_instrumentation(_)
    VCAP::CloudController::Dea::AppStagerTask.class_eval do
      include ::NewRelic::Agent::MethodTracer

      %w(
        stage
      ).each do |method_name|
        add_method_tracer(method_name)
      end
    end
  end
end
