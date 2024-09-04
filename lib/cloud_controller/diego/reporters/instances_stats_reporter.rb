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
        logger.debug('stats_for_app.fetching_container_metrics', process_guid: process.guid)
        desired_lrp = bbs_instances_client.desired_lrp_instance(process)

        log_cache_errors, stats, quota_stats, isolation_segment = get_stats(desired_lrp, process)

        actual_lrp_info(process, stats, quota_stats, log_cache_errors, isolation_segment)
      rescue CloudController::Errors::NoRunningInstances
        handle_no_running_instances(process)
      rescue StandardError => e
        logger.error('stats_for_app.error', error: e.to_s)
        raise e if e.is_a?(CloudController::Errors::ApiError) && e.name == 'ServiceUnavailable'

        exception = CloudController::Errors::InstancesUnavailable.new(e.message)
        exception.set_backtrace(e.backtrace)
        raise exception
      end

      private

      attr_reader :bbs_instances_client

      def get_stats(desired_lrp, process)
        log_cache_data, log_cache_errors = envelopes(desired_lrp, process)
        stats = formatted_process_stats(log_cache_data, Time.now.to_datetime.rfc3339)
        quota_stats = formatted_quota_stats(log_cache_data)
        isolation_segment = desired_lrp.PlacementTags.first
        [log_cache_errors, stats, quota_stats, isolation_segment]
      end

      # rubocop:disable Metrics/ParameterLists
      def actual_lrp_info(process, stats=nil, quota_stats=nil, log_cache_errors=nil, isolation_segment=nil, state=nil)
        # rubocop:enable Metrics/ParameterLists
        result = {}
        bbs_instances_client.lrp_instances(process).each do |actual_lrp|
          next unless actual_lrp.actual_lrp_key.index < process.instances

          lrp_state = state || LrpStateTranslator.translate_lrp_state(actual_lrp)

          info = build_info(lrp_state, actual_lrp, process, stats, quota_stats, log_cache_errors)
          info[:isolation_segment] = isolation_segment unless isolation_segment.nil?
          result[actual_lrp.actual_lrp_key.index] = info
        end

        fill_unreported_instances_with_down_instances(result, process, flat: false)

        warnings = [log_cache_errors].compact
        [result, warnings]
      end

      def build_info(state, actual_lrp, process, stats, quota_stats, log_cache_errors)
        info = {
          state: state,
          stats: {
            name: process.name,
            uris: process.uris,
            host: actual_lrp.actual_lrp_net_info.address,
            port: get_default_port(actual_lrp.actual_lrp_net_info),
            net_info: actual_lrp.actual_lrp_net_info.to_h,
            uptime: nanoseconds_to_seconds((Time.now.to_f * 1e9) - actual_lrp.since),
            fds_quota: process.file_descriptors
          }.merge(metrics_data_for_instance(stats, quota_stats, log_cache_errors, Time.now.to_datetime.rfc3339, actual_lrp.actual_lrp_key.index))
        }
        info[:details] = actual_lrp.placement_error if actual_lrp.placement_error.present?

        info[:routable] = (actual_lrp.routable if actual_lrp.optional_routable)
        info
      end

      def handle_no_running_instances(process)
        # case when no actual_lrp exists
        if bbs_instances_client.lrp_instances(process).empty?
          [fill_unreported_instances_with_down_instances({}, process, flat: false), []]
        else
          # case when no desired_lrp exists but an actual_lrp
          logger.debug('Actual LRP found, setting state to STOPPING', process_guid: process.guid)
          actual_lrp_info(process, nil, nil, nil, nil, VCAP::CloudController::Diego::LRP_STOPPING)
        end
      rescue CloudController::Errors::NoRunningInstances => e
        logger.info('stats_for_app.error', error: e.to_s)
        [fill_unreported_instances_with_down_instances({}, process, flat: false), []]
      end

      def metrics_data_for_instance(stats, quota_stats, log_cache_errors, formatted_current_time, index)
        if !stats.nil? && log_cache_errors.blank?
          {
            mem_quota: quota_stats[index]&.memory_bytes_quota,
            disk_quota: quota_stats[index]&.disk_bytes_quota,
            log_rate_limit: quota_stats[index]&.log_rate_limit,
            usage: stats[index] || missing_process_stats(formatted_current_time)
          }
        else
          {
            mem_quota: nil,
            disk_quota: nil,
            log_rate_limit: nil,
            usage: {}
          }
        end
      end

      def missing_process_stats(formatted_current_time)
        {
          time: formatted_current_time,
          cpu: 0,
          cpu_entitlement: 0,
          mem: 0,
          disk: 0,
          log_rate: 0
        }
      end

      def formatted_process_stats(log_cache_data, formatted_current_time)
        log_cache_data.
          map do |e|
            [
              e.instance_index,
              converted_container_metrics(e, formatted_current_time)
            ]
          end.to_h
      end

      def formatted_quota_stats(log_cache_data)
        log_cache_data.
          index_by(&:instance_index)
      end

      def envelopes(desired_lrp, process)
        if desired_lrp.metric_tags['process_id']
          filter = ->(envelope) { envelope.tags.any? { |key, value| key == 'process_id' && value == process.guid } }
          source_guid = process.app_guid
        else
          filter = ->(_) { true }
          source_guid = process.guid
        end

        [@logstats_client.container_metrics(
          source_guid: source_guid,
          logcache_filter: filter
        ), nil]
      rescue GRPC::BadStatus, CloudController::Errors::ApiError => e
        logger.error('stats_for_app.error', error: e.message, backtrace: e.backtrace.join("\n"))
        [[], 'Stats server temporarily unavailable.']
      end

      def logger
        @logger ||= Steno.logger('cc.diego.instances_reporter')
      end

      def converted_container_metrics(container_metrics, formatted_current_time)
        cpu = container_metrics.cpu_percentage
        cpu_entitlement = container_metrics.cpu_entitlement_percentage.nil? ? nil : container_metrics.cpu_entitlement_percentage / 100
        mem = container_metrics.memory_bytes
        disk = container_metrics.disk_bytes
        log_rate = container_metrics.log_rate

        if cpu.nil? || mem.nil? || disk.nil? || log_rate.nil?
          missing_process_stats(formatted_current_time)
        else
          {
            time: formatted_current_time,
            cpu: cpu / 100,
            cpu_entitlement: cpu_entitlement,
            mem: mem,
            disk: disk,
            log_rate: log_rate
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
