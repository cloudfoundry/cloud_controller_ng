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
        uniq { |e| e.gauge.metrics.keys << e.instance_id }.
        sort_by(&:instance_id).
        chunk(&:instance_id).
        map { |envelopes_by_instance| convert_to_traffic_controller_envelope(source_guid, envelopes_by_instance) }
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
      envelope.gauge.metrics.has_key?('cpu') ||
      envelope.gauge.metrics.has_key?('memory') ||
      envelope.gauge.metrics.has_key?('disk')
      # rubocop:enable Style/PreferredHashMethods
    end

    def convert_to_traffic_controller_envelope(source_guid, envelopes_by_instance)
      tc_envelope = TrafficController::Models::Envelope.new(
        containerMetric: TrafficController::Models::ContainerMetric.new({
          applicationId: source_guid,
          instanceIndex: envelopes_by_instance.first,
        }),
      )

      tags = {}
      envelopes_by_instance.second.each { |e|
        tc_envelope.containerMetric.instanceIndex = e.instance_id
        # rubocop seems to think that there is a 'key?' method
        # on envelope.gauge.metrics - but it does not
        # rubocop:disable Style/PreferredHashMethods
        if e.gauge.metrics.has_key?('cpu')
          tc_envelope.containerMetric.cpuPercentage = e.gauge.metrics['cpu'].value
        end
        if e.gauge.metrics.has_key?('memory')
          tc_envelope.containerMetric.memoryBytes = e.gauge.metrics['memory'].value
        end
        if e.gauge.metrics.has_key?('disk')
          tc_envelope.containerMetric.diskBytes = e.gauge.metrics['disk'].value
        end
        if e.gauge.metrics.has_key?('disk_quota')
          tc_envelope.containerMetric.diskBytesQuota = e.gauge.metrics['disk_quota'].value
        end
        if e.gauge.metrics.has_key?('memory_quota')
          tc_envelope.containerMetric.memoryBytesQuota = e.gauge.metrics['memory_quota'].value
        end
        # rubocop:enable Style/PreferredHashMethods

        tags.merge!(e.tags.to_h)
      }

      tc_envelope.tags = tags.map { |k, v| TrafficController::Models::Envelope::TagsEntry.new(key: k, value: v) }

      tc_envelope
    end

    def logger
      @logger ||= Steno.logger('cc.logcache_stats')
    end
  end
end
