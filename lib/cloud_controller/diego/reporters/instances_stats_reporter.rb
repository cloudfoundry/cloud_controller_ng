require 'traffic_controller/client'
require 'logcache/client'
require 'cloud_controller/diego/reporters/reporter_mixins'

module VCAP::CloudController
  module Diego
    class InstancesStatsReporter
      include ReporterMixins

      def initialize(bbs_instances_client, logstats_client)
        @bbs_instances_client = bbs_instances_client
        @logstats_client = logstats_client
      end

      def stats_for_app(process)
        result       = {}
        current_time = Time.now.to_f
        formatted_current_time = Time.now.to_datetime.rfc3339

        logger.debug('stats_for_app.fetching_container_metrics', process_guid: process.guid)
        desired_lrp = bbs_instances_client.desired_lrp_instance(process)

        log_cache_data, log_cache_errors = envelopes(desired_lrp, process)
        stats = formatted_process_stats(log_cache_data, formatted_current_time)
        quota_stats = formatted_quota_stats(log_cache_data)

        bbs_instances_client.lrp_instances(process).each do |actual_lrp|
          index = actual_lrp.actual_lrp_key.index
          next unless index < process.instances

          info = {
            state: LrpStateTranslator.translate_lrp_state(actual_lrp),
            isolation_segment: desired_lrp.PlacementTags.first,
            stats: {
              name:       process.name,
              uris:       process.uris,
              host:       actual_lrp.actual_lrp_net_info.address,
              port:       get_default_port(actual_lrp.actual_lrp_net_info),
              net_info:   actual_lrp.actual_lrp_net_info.to_h,
              uptime:     nanoseconds_to_seconds(current_time * 1e9 - actual_lrp.since),
              fds_quota:  process.file_descriptors,
            }.merge(metrics_data_for_instance(stats, quota_stats, log_cache_errors, formatted_current_time, index))
          }
          info[:details]                          = actual_lrp.placement_error if actual_lrp.placement_error.present?
          result[actual_lrp.actual_lrp_key.index] = info
        end

        fill_unreported_instances_with_down_instances(result, process)

        warnings = [log_cache_errors].compact
        return result, warnings
      rescue CloudController::Errors::NoRunningInstances => e
        logger.info('stats_for_app.error', error: e.to_s)
        return fill_unreported_instances_with_down_instances({}, process), []
      rescue StandardError => e
        logger.error('stats_for_app.error', error: e.to_s)
        if e.is_a?(CloudController::Errors::ApiError) && e.name == 'ServiceUnavailable'
          raise e
        end

        exception = CloudController::Errors::InstancesUnavailable.new(e.message)
        exception.set_backtrace(e.backtrace)
        raise exception
      end

      private

      attr_reader :bbs_instances_client

      def metrics_data_for_instance(stats, quota_stats, log_cache_errors, formatted_current_time, index)
        if log_cache_errors.blank?
          {
            mem_quota:  quota_stats[index]&.memoryBytesQuota,
            disk_quota: quota_stats[index]&.diskBytesQuota,
            usage:      stats[index] || missing_process_stats(formatted_current_time)
          }
        else
          {
            mem_quota: nil,
            disk_quota: nil,
            usage: {}
          }
        end
      end

      def missing_process_stats(formatted_current_time)
        {
          time: formatted_current_time,
          cpu:  0,
          mem:  0,
          disk: 0,
        }
      end

      def formatted_process_stats(log_cache_data, formatted_current_time)
        log_cache_data.
          map { |e|
            [
              e.containerMetric.instanceIndex,
              converted_container_metrics(e.containerMetric, formatted_current_time),
            ]
          }.to_h
      end

      def formatted_quota_stats(log_cache_data)
        log_cache_data.
          map { |e|
            [
              e.containerMetric.instanceIndex,
              e.containerMetric,
            ]
          }.to_h
      end

      def envelopes(desired_lrp, process)
        if desired_lrp.metric_tags['process_id']
          filter = ->(envelope) { envelope.tags.any? { |key, value| key == 'process_id' && value == process.guid } }
          source_guid = process.app.guid
        else
          filter = ->(_) { true }
          source_guid = process.guid
        end

        return @logstats_client.container_metrics(
          source_guid: source_guid,
          auth_token: VCAP::CloudController::SecurityContext.auth_token,
          logcache_filter: filter
        ), nil
      rescue GRPC::BadStatus, CloudController::Errors::ApiError => e
        logger.error('stats_for_app.error', error: e.message, backtrace: e.backtrace.join("\n"))
        return [], 'Stats server temporarily unavailable.'
      end

      def logger
        @logger ||= Steno.logger('cc.diego.instances_reporter')
      end

      def converted_container_metrics(container_metrics, formatted_current_time)
        cpu = container_metrics.cpuPercentage
        mem = container_metrics.memoryBytes
        disk = container_metrics.diskBytes

        if cpu.nil? || mem.nil? || disk.nil?
          missing_process_stats(formatted_current_time)
        else
          {
            time: formatted_current_time,
            cpu: cpu / 100,
            mem:  mem,
            disk: disk
          }
        end
      end

      def get_default_port(net_info)
        net_info.ports.each do |port_mapping|
          return port_mapping.host_port if port_mapping.container_port == DEFAULT_APP_PORT
        end

        0
      end
    end
  end
end
