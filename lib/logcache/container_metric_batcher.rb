require 'logcache/client'
require 'utils/time_utils'
require 'logcache/container_metric_batch'

module Logcache
  class ContainerMetricBatcher
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
        map { |envelopes_by_instance| batch_metrics(source_guid, envelopes_by_instance) }
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
      envelope.gauge.metrics.has_key?('memory_quota') ||
      envelope.gauge.metrics.has_key?('disk') ||
      envelope.gauge.metrics.has_key?('disk_quota') ||
      envelope.gauge.metrics.has_key?('log_rate') ||
      envelope.gauge.metrics.has_key?('log_rate_limit')
      # rubocop:enable Style/PreferredHashMethods
    end

    def batch_metrics(source_guid, envelopes_by_instance)
      metric_batch = ContainerMetricBatch.new
      metric_batch.instance_index = envelopes_by_instance.first.to_i

      envelopes_by_instance.second.each { |e|
        # rubocop seems to think that there is a 'key?' method
        # on envelope.gauge.metrics - but it does not
        # rubocop:disable Style/PreferredHashMethods
        if e.gauge.metrics.has_key?('cpu')
          metric_batch.cpu_percentage = e.gauge.metrics['cpu'].value
        end
        if e.gauge.metrics.has_key?('memory')
          metric_batch.memory_bytes = e.gauge.metrics['memory'].value.to_i
        end
        if e.gauge.metrics.has_key?('disk')
          metric_batch.disk_bytes = e.gauge.metrics['disk'].value.to_i
        end
        if e.gauge.metrics.has_key?('log_rate')
          metric_batch.log_rate = e.gauge.metrics['log_rate'].value.to_i
        end
        if e.gauge.metrics.has_key?('disk_quota')
          metric_batch.disk_bytes_quota = e.gauge.metrics['disk_quota'].value.to_i
        end
        if e.gauge.metrics.has_key?('memory_quota')
          metric_batch.memory_bytes_quota = e.gauge.metrics['memory_quota'].value.to_i
        end
        if e.gauge.metrics.has_key?('log_rate_limit')
          metric_batch.log_rate_limit = e.gauge.metrics['log_rate_limit'].value.to_i
        end
        # rubocop:enable Style/PreferredHashMethods
      }

      metric_batch
    end

    def logger
      @logger ||= Steno.logger('cc.logcache_stats')
    end
  end
end
