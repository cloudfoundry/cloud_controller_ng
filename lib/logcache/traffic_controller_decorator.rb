require 'logcache/client'
require 'utils/time_utils'

module Logcache
  class TrafficControllerDecorator
    MAX_REQUEST_COUNT = 100

    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(auth_token: nil, source_guid:)
      now = Time.now
      start_time = TimeUtils.to_nanoseconds(now - 2.minutes)
      end_time = TimeUtils.to_nanoseconds(now)
      final_envelopes = []
      request_count = 0

      loop do
        new_envelopes = get_container_metrics(
          start_time: start_time,
          end_time: end_time,
          source_guid: source_guid
        )

        final_envelopes += new_envelopes
        break if all_metrics_retrieved?(new_envelopes)
        end_time = new_envelopes.last.timestamp - 1

        request_count += 1
        if request_count >= MAX_REQUEST_COUNT
          logger.warn("Max requests hit for process #{source_guid}")
          break
        end
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

    def all_metrics_retrieved?(envelopes)
      envelopes.size < Logcache::Client::MAX_LIMIT
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

    def logger
      @logger ||= Steno.logger('cc.logcache_stats')
    end
  end
end
