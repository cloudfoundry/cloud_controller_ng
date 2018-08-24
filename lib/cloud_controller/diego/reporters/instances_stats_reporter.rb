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
        envelopes = @logstats_client.container_metrics(
          source_guid: process.guid,
          auth_token: VCAP::CloudController::SecurityContext.auth_token,
        )
        actual_lrps = bbs_instances_client.lrp_instances(process)
        desired_lrp = bbs_instances_client.desired_lrp_instance(process)

        stats = {}
        envelopes.each do |envelope|
          container_metrics                      = envelope.containerMetric
          stats[container_metrics.instanceIndex] = {
            time: formatted_current_time
          }.merge(converted_container_metrics(container_metrics))
        end

        actual_lrps.each do |actual_lrp|
          next unless actual_lrp.actual_lrp_key.index < process.instances
          info = {
            state: LrpStateTranslator.translate_lrp_state(actual_lrp),
            isolation_segment: desired_lrp.PlacementTags.first,
            stats: {
              name:       process.name,
              uris:       process.uris,
              host:       actual_lrp.actual_lrp_net_info.address,
              port:       get_default_port(actual_lrp.actual_lrp_net_info),
              net_info:   actual_lrp.actual_lrp_net_info.to_hash,
              uptime:     nanoseconds_to_seconds(current_time * 1e9 - actual_lrp.since),
              mem_quota:  process[:memory] * 1024 * 1024,
              disk_quota: process[:disk_quota] * 1024 * 1024,
              fds_quota:  process.file_descriptors,
              usage:      stats[actual_lrp.actual_lrp_key.index] || {
                time: formatted_current_time,
                cpu:  0,
                mem:  0,
                disk: 0,
              },
            }
          }
          info[:details]                          = actual_lrp.placement_error if actual_lrp.placement_error.present?
          result[actual_lrp.actual_lrp_key.index] = info
        end

        fill_unreported_instances_with_down_instances(result, process)
      rescue CloudController::Errors::NoRunningInstances => e
        logger.info('stats_for_app.error', error: e.to_s)
        fill_unreported_instances_with_down_instances({}, process)
      rescue => e
        logger.error('stats_for_app.error', error: e.to_s)
        raise CloudController::Errors::InstancesUnavailable.new(e)
      end

      private

      attr_reader :bbs_instances_client

      def logger
        @logger ||= Steno.logger('cc.diego.instances_reporter')
      end

      def converted_container_metrics(container_metrics)
        cpu = container_metrics.cpuPercentage
        mem = container_metrics.memoryBytes
        disk = container_metrics.diskBytes

        if cpu.nil? || mem.nil? || disk.nil?
          {
            cpu: 0,
            mem: 0,
            disk: 0
          }
        else
          {
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
