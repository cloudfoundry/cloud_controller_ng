require 'logcache/client'
require 'utils/time_utils'

module Logcache
  class TrafficControllerDecorator
    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(auth_token: nil, source_guid:)
      now = Time.now
      start_time = TimeUtils.to_nanoseconds(now - 2.minutes)
      end_time = TimeUtils.to_nanoseconds(now)
      final_envelopes = []

      loop do
        new_envelopes = get_container_metrics(
          start_time: start_time,
          end_time: end_time,
          source_guid: source_guid
        )

        final_envelopes += new_envelopes
        break if new_envelopes.size < Logcache::Client::MAX_LIMIT

        end_time = new_envelopes.last.timestamp - 1
      end

      final_envelopes.uniq(&:instance_id).map do |envelope|
        convert_to_traffic_controller_envelope(source_guid, envelope)
      end
    end

    private

    def get_container_metrics(start_time:, end_time:, source_guid:)
      @logcache_client.container_metrics(
        start_time: start_time,
        end_time: end_time,
        source_guid: source_guid,
        envelope_limit: Logcache::Client::MAX_LIMIT
      ).envelopes.batch
    end

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
  end
end
