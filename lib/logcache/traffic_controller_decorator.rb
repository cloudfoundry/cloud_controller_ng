require 'logcache/client'
require 'utils/time_utils'

module Logcache
  class TrafficControllerDecorator
    MAX_REQUEST_COUNT = 100

    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(auth_token: nil, source_guid:, logcache_filter:)
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

      final_envelopes.
        select { |e| has_container_metrics_fields?(e) && logcache_filter.call(e) }.
        uniq(&:instance_id).
        map { |e| convert_to_traffic_controller_envelope(source_guid, e) }
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

    def has_container_metrics_fields?(envelope)
      # rubocop seems to think that there is a 'key?' method
      # on envelope.gauge.metrics - but it does not
      # rubocop:disable Style/PreferredHashMethods
      envelope.gauge.metrics.has_key?('cpu') &&
      envelope.gauge.metrics.has_key?('memory') &&
      envelope.gauge.metrics.has_key?('disk')
      # rubocop:enable Style/PreferredHashMethods
    end

    def convert_to_traffic_controller_envelope(source_guid, logcache_envelope)
      TrafficController::Models::Envelope.new(
        containerMetric: TrafficController::Models::ContainerMetric.new({
          applicationId: source_guid,
          instanceIndex: logcache_envelope.instance_id,
          cpuPercentage: logcache_envelope.gauge.metrics['cpu'].value,
          memoryBytes: logcache_envelope.gauge.metrics['memory'].value,
          diskBytes: logcache_envelope.gauge.metrics['disk'].value,
        }),
        tags: logcache_envelope.tags.map { |k, v| TrafficController::Models::Envelope::TagsEntry.new(key: k, value: v) },
      )
    end

    def logger
      @logger ||= Steno.logger('cc.logcache_stats')
    end
  end
end
