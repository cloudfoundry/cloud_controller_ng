require 'new_relic/agent/method_tracer'
require 'loggregator'

module CCInitializers
  def self.new_relic_loggregator_instrumentation(_)
    Loggregator.class_eval do
      include ::NewRelic::Agent::MethodTracer

      class << self
        %w(
          emit
          emit_error
        ).each do |method_name|
          add_method_tracer(
            method_name,
            "Custom/Loggregator/#{method_name}",
            push_scope: true,
            metric: true,
          )
        end
      end
    end
  end
end
