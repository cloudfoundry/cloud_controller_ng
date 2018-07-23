module Logcache
  class TrafficControllerDecorator
    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(auth_token: nil, app_guid:)
      num_instances = VCAP::CloudController::AppModel.find(guid: app_guid).web_process.instances
      return_array = Array.new(num_instances)
      logcache_response = @logcache_client.container_metrics(app_guid: app_guid)

      envelopes = logcache_response.envelopes.batch.reject { |env| env.instance_id.to_i > num_instances }
      while envelopes.size > 0
        envelope = envelopes.shift
        new_envelope = {
          applicationId: app_guid,
          instanceIndex: envelope.instance_id,
        }
        if (metrics = envelope.gauge&.metrics)
          gauge_values = {
            cpuPercentage: metrics['cpu']&.value,
            memoryBytes: metrics['memory']&.value,
            diskBytes: metrics['disk']&.value
          }
          new_envelope.merge!(gauge_values)
        end
        return_array[envelope.instance_id.to_i - 1] = TrafficController::Models::Envelope.new(
          containerMetric: TrafficController::Models::ContainerMetric.new(new_envelope)
        )
        envelopes = envelopes.reject { |env| env.instance_id == envelope.instance_id }
      end
      return_array.compact
    end
  end
end
