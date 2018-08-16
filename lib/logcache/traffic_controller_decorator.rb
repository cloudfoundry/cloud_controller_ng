require 'logcache/client'

module Logcache
  class TrafficControllerDecorator
    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(auth_token: nil, source_guid:)
      current_desired_instance_count = VCAP::CloudController::ProcessModel.find(guid: source_guid).instances
      envelopes = @logcache_client.container_metrics(
        source_guid: source_guid,
        envelope_limit: num_envelopes_to_fetch(current_desired_instance_count)
      ).envelopes.batch

      envelopes.uniq(&:instance_id).map { |envelope| convert_to_traffic_controller_envelope(source_guid, envelope) }
    end

    private

    def convert_to_traffic_controller_envelope(source_guid, logcache_envelope)
      new_envelope = {
        applicationId: source_guid,
        instanceIndex: logcache_envelope.instance_id,
      }

      if (metrics = logcache_envelope.gauge&.metrics)
        gauge_values = {
          cpuPercentage: metrics['cpu']&.value,
          memoryBytes: metrics['memory']&.value,
          diskBytes: metrics['disk']&.value
        }
        new_envelope.merge!(gauge_values)
      end

      TrafficController::Models::Envelope.new(
        containerMetric: TrafficController::Models::ContainerMetric.new(new_envelope)
      )
    end

    def num_envelopes_to_fetch(num_instances)
      process_count_with_padding = num_instances * 2

      [[process_count_with_padding, Logcache::Client::MAX_LIMIT].min, Logcache::Client::DEFAULT_LIMIT].max
    end
  end
end
