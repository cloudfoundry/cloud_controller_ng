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
        # desired_lrp used for isolation segment (which should be retrievable through spaces table)
        # also used for metric_tags['process_id'] which filters for the process_id and uses app_guid as source_id -> also not needed when using promql
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

      # Fetch stats for multiple processes, fetching desired_lrps, actual_lrps, and metrics in parallel
      # @param processes [Array<Process>] List of process objects
      # @return [Hash{Process=>[result, warnings]}] Hash mapping each process to its stats and warnings
      def stats_for_processes(processes)
        desired_lrps = nil
        actual_lrps = nil
        metrics_results = nil

        logger.info('stats_for_processes.fetching_data.start')

        threads = []
        threads << Thread.new do
          start_time = Time.now
          desired_lrps = fetch_desired_lrps_parallel(processes)
          logger.info('stats_for_processes.fetch_desired_lrps_parallel.time', duration: Time.now - start_time)
        end
        threads << Thread.new do
          start_time = Time.now
          actual_lrps = fetch_actual_lrps_parallel(processes)
          logger.info('stats_for_processes.fetch_actual_lrps_parallel.time', duration: Time.now - start_time)
        end
        threads << Thread.new do
          start_time = Time.now
          metrics_results = fetch_metrics_for_processes(processes)
          logger.info('stats_for_processes.fetch_metrics_for_processes.time', duration: Time.now - start_time)
        end
        threads.each(&:join)

        logger.info('stats_for_processes.fetching_data.finished')

        results = {}
        processes.each do |process|
          desired_lrp = desired_lrps[process.guid]
          actual_lrp_list = actual_lrps[process.guid]
          process_metrics = metrics_results[process.guid] || {}
          warnings = []

          # Prepare stats and quota_stats using formatted_process_stats and formatted_quota_stats
          formatted_current_time = Time.now.to_datetime.rfc3339
          log_cache_data = process_metrics.values # instance_id => ContainerMetricBatch

          stats = formatted_process_stats(log_cache_data, formatted_current_time)
          quota_stats = formatted_quota_stats(log_cache_data)
          isolation_segment = desired_lrp.is_a?(Exception) ? nil : desired_lrp.PlacementTags.first

          instance_stats = {}
          lrp_instances = {}

          if actual_lrp_list.is_a?(Exception)
            warnings << actual_lrp_list.message
            actual_lrp_list = []
          end

          actual_lrp_list.each do |actual_lrp|
            idx = actual_lrp.actual_lrp_key.index

            # if an LRP already exists with the same index use the one with the latest since value
            if lrp_instances.include?(idx)
              existing_lrp = lrp_instances[idx]
              next if actual_lrp.since < existing_lrp.since
            end

            # Use build_info to construct the stats hash for this instance
            lrp_state = LrpStateTranslator.translate_lrp_state(actual_lrp)
            info = build_info(lrp_state, actual_lrp, process, stats, quota_stats, nil)
            info[:isolation_segment] = isolation_segment unless isolation_segment.nil?
            instance_stats[idx] = info
            lrp_instances[idx] = actual_lrp
          end

          fill_unreported_instances_with_down_instances(instance_stats, process, flat: false)

          results[process] = [instance_stats, warnings]
        end

        logger.info('stats_for_processes.success', results:)

        results
      end

      # Fetch desired_lrps for a list of processes in parallel
      # @param processes [Array<Process>] List of process objects
      # @return [Hash{String=>DesiredLRP}] Hash mapping process.guid to desired_lrp or exception
      def fetch_desired_lrps_parallel(processes)
        desired_lrp_threads = {}
        desired_lrps = {}
        processes.each do |process|
          desired_lrp_threads[process.guid] = Thread.new do
            desired_lrps[process.guid] = bbs_instances_client.desired_lrp_instance(process)
          rescue StandardError => e
            desired_lrps[process.guid] = e
          end
        end
        desired_lrp_threads.each_value(&:join)
        desired_lrps
      end

      # Fetch actual_lrps for a list of processes in parallel
      # @param processes [Array<Process>] List of process objects
      # @return [Hash{String=>Array<ActualLRP>|Exception}] Hash mapping process.guid to actual_lrps or exception
      def fetch_actual_lrps_parallel(processes)
        actual_lrp_threads = {}
        actual_lrps = {}
        processes.each do |process|
          actual_lrp_threads[process.guid] = Thread.new do
            actual_lrps[process.guid] = bbs_instances_client.lrp_instances(process)
          rescue StandardError => e
            actual_lrps[process.guid] = e
          end
        end
        actual_lrp_threads.each_value(&:join)
        actual_lrps
      end

      # Fetches all metrics in parallel for a list of processes using app_guids as source_ids, then filters for the requested processes
      # @param processes [Array<Process>] List of process objects
      # @param time [String] The time for the instant query (must be a unix timestamp)
      # @return [Hash{String=>Hash{String=>ContainerMetricBatch}}] Hash: process_id => instance_id => batch, filtered for requested processes
      def fetch_metrics_for_processes(processes)
        app_guids = processes.map(&:app_guid).uniq
        process_guids = processes.map(&:guid)
        # Get all metrics for the relevant app_guids
        all_metrics = @logstats_client.container_metrics_from_promql(source_ids: app_guids)
        # Merge all instance_hashes for each process_id across all source_ids
        processes_metrics = {}
        all_metrics.each_value do |process_hash|
          process_hash.each do |process_id, instance_hash|
            next unless process_guids.include?(process_id)

            processes_metrics[process_id] ||= {}
            processes_metrics[process_id].merge!(instance_hash)
          end
        end
        processes_metrics
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
        lrp_instances = {}

        bbs_instances_client.lrp_instances(process).each do |actual_lrp|
          next unless actual_lrp.actual_lrp_key.index < process.instances

          # if an LRP already exists with the same index use the one with the latest since value
          if lrp_instances.include?(actual_lrp.actual_lrp_key.index)
            existing_lrp = lrp_instances[actual_lrp.actual_lrp_key.index]
            next if actual_lrp.since < existing_lrp.since
          end

          lrp_state = state || LrpStateTranslator.translate_lrp_state(actual_lrp)
          info = build_info(lrp_state, actual_lrp, process, stats, quota_stats, log_cache_errors)
          info[:isolation_segment] = isolation_segment unless isolation_segment.nil?
          result[actual_lrp.actual_lrp_key.index] = info
          lrp_instances[actual_lrp.actual_lrp_key.index] = actual_lrp
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
            instance_guid: actual_lrp.actual_lrp_instance_key.instance_guid,
            port: get_default_port(actual_lrp.actual_lrp_net_info),
            net_info: actual_lrp_net_info_to_hash(actual_lrp.actual_lrp_net_info),
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
          state = Config.config.get(:app_instance_stopping_state) ? VCAP::CloudController::Diego::LRP_STOPPING : VCAP::CloudController::Diego::LRP_DOWN
          # case when no desired_lrp exists but an actual_lrp
          logger.debug("Actual LRP found, setting state to #{state}", process_guid: process.guid)
          actual_lrp_info(process, nil, nil, nil, nil, state)
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

      def actual_lrp_net_info_to_hash(net_info)
        %i[address instance_address ports preferred_address].index_with do |field_name|
          if field_name == :ports
            net_info.ports.map(&method(:port_mapping_to_hash))
          else
            net_info.send(field_name)
          end
        end
      end

      def port_mapping_to_hash(port_mapping)
        %i[container_port container_tls_proxy_port host_port host_tls_proxy_port].index_with do |field_name|
          port_mapping.send(field_name)
        end
      end
    end
  end
end
