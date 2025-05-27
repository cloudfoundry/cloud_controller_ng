require 'logcache/client'
require 'utils/time_utils'
require 'logcache/container_metric_batch'

module Logcache
  class ContainerMetricBatcher
    MAX_REQUEST_COUNT = 100

    def initialize(logcache_client)
      @logcache_client = logcache_client
    end

    def container_metrics(source_guid:, logcache_filter:)
      now = Time.now
      start_time = TimeUtils.to_nanoseconds(now - 2.minutes)
      end_time = TimeUtils.to_nanoseconds(now)
      final_envelopes = []
      request_count = 0

      loop do
        new_envelopes = get_container_metrics(
          start_time:,
          end_time:,
          source_guid:
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

      grouped_batches = Hash.new { |h, k| h[k] = [] }

      final_envelopes.
        select { |e| has_container_metrics_fields?(e) && logcache_filter.call(e) && e.tags['process_id'] }.
        sort_by { |e| [e.tags['process_id'], e.instance_id] }.
        chunk { |e| [e.tags['process_id'], e.instance_id] }.
        each do |(process_id, _instance_id), envelopes_by_instance|
          # Ensure envelopes are sorted by timestamp so the most recent value is last
          sorted_envelopes = envelopes_by_instance.sort_by(&:timestamp)
          batch = batch_metrics(source_guid, sorted_envelopes)
          grouped_batches[process_id] << batch
        end

      grouped_batches
    end

    # Alternative to container_metrics: fetches metrics using PromQL and returns a nested hash
    # @param source_ids [Array<String>] The app GUIDs (source_ids)
    # @return [Hash{String=>Hash{String=>Hash{String=>ContainerMetricBatch}}}]
    #         Hash of metric batches: source_id => process_id => instance_id => batch
    def container_metrics_from_promql(source_ids:)
      start_time = Time.now
      promql_response = @logcache_client.fetch_all_metrics_parallel(source_ids)
      logger.info('container_metrics_from_promql', duration: Time.now - start_time)
      # Structure: { source_id => { process_id => { instance_id => batch } } }
      batches = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }

      promql_response.each do |metric_name, result|
        next unless result.respond_to?(:vector) && result.vector.respond_to?(:samples)

        result.vector.samples.each do |sample|
          source_id = sample.metric['source_id']
          process_id = sample.metric['process_id']
          instance_id = sample.metric['instance_id']
          next unless source_id && process_id && instance_id

          batches[source_id][process_id][instance_id] ||= ContainerMetricBatch.new
          batch = batches[source_id][process_id][instance_id]
          batch.instance_index = instance_id.to_i

          value = sample.point.value
          case metric_name
          when 'cpu'
            batch.cpu_percentage = value
          when 'cpu_entitlement'
            batch.cpu_entitlement_percentage = value
          when 'memory'
            batch.memory_bytes = value.to_i
          when 'disk'
            batch.disk_bytes = value.to_i
          when 'log_rate'
            batch.log_rate = value.to_i
          when 'disk_quota'
            batch.disk_bytes_quota = value.to_i
          when 'memory_quota'
            batch.memory_bytes_quota = value.to_i
          when 'log_rate_limit'
            batch.log_rate_limit = value.to_i
          end
        end
      end

      batches
    end

    private

    def get_container_metrics(start_time:, end_time:, source_guid:)
      # promql_response = @logcache_client.fetch_all_metrics_parallel([source_guid])

      # logger.info("PromQL metrics for source_id #{source_guid}: #{promql_response}")

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
        envelope.gauge.metrics.has_key?('cpu_entitlement') ||
        envelope.gauge.metrics.has_key?('memory') ||
        envelope.gauge.metrics.has_key?('memory_quota') ||
        envelope.gauge.metrics.has_key?('disk') ||
        envelope.gauge.metrics.has_key?('disk_quota') ||
        envelope.gauge.metrics.has_key?('log_rate') ||
        envelope.gauge.metrics.has_key?('log_rate_limit')
      # rubocop:enable Style/PreferredHashMethods
    end

    def batch_metrics(_source_guid, envelopes_by_instance)
      metric_batch = ContainerMetricBatch.new
      metric_batch.instance_index = envelopes_by_instance.first.instance_id.to_i

      envelopes_by_instance.each do |e|
        # rubocop seems to think that there is a 'key?' method
        # on envelope.gauge.metrics - but it does not
        # rubocop:disable Style/PreferredHashMethods
        metric_batch.cpu_percentage = e.gauge.metrics['cpu'].value if e.gauge.metrics.has_key?('cpu')
        metric_batch.cpu_entitlement_percentage = e.gauge.metrics['cpu_entitlement'].value if e.gauge.metrics.has_key?('cpu_entitlement')
        metric_batch.memory_bytes = e.gauge.metrics['memory'].value.to_i if e.gauge.metrics.has_key?('memory')
        metric_batch.disk_bytes = e.gauge.metrics['disk'].value.to_i if e.gauge.metrics.has_key?('disk')
        metric_batch.log_rate = e.gauge.metrics['log_rate'].value.to_i if e.gauge.metrics.has_key?('log_rate')
        metric_batch.disk_bytes_quota = e.gauge.metrics['disk_quota'].value.to_i if e.gauge.metrics.has_key?('disk_quota')
        metric_batch.memory_bytes_quota = e.gauge.metrics['memory_quota'].value.to_i if e.gauge.metrics.has_key?('memory_quota')
        metric_batch.log_rate_limit = e.gauge.metrics['log_rate_limit'].value.to_i if e.gauge.metrics.has_key?('log_rate_limit')
        # rubocop:enable Style/PreferredHashMethods
      end

      metric_batch
    end

    def logger
      @logger ||= Steno.logger('cc.logcache_stats')
    end
  end
end
