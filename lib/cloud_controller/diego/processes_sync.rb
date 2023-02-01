require 'utils/workpool'

module VCAP::CloudController
  module Diego
    class ProcessesSync
      BATCH_SIZE = 500

      class Error < StandardError
      end
      class BBSFetchError < Error
      end

      def initialize(config:, statsd_updater: VCAP::CloudController::Metrics::StatsdUpdater.new)
        @config   = config
        @workpool = WorkPool.new(50, store_exceptions: true)
        @statsd_updater = statsd_updater
      end

      def sync
        logger.info('run-process-sync')
        @bump_freshness = true
        diego_lrps = bbs_apps_client.fetch_scheduling_infos.index_by { |d| d.desired_lrp_key.process_guid }
        logger.info('fetched-scheduling-infos')

        batched_processes do |processes|
          processes.each do |process|
            process_guid = ProcessGuid.from_process(process)
            diego_lrp    = diego_lrps.delete(process_guid)

            if diego_lrp.nil?
              workpool.submit(process) do |p|
                logger.info('desiring-lrp', process_guid: p.guid, app_guid: p.app_guid)
                bbs_apps_client.desire_app(p)
                logger.info('desire-lrp', process_guid: p.guid)
              end
            elsif process.updated_at.to_f.to_s != diego_lrp.annotation
              workpool.submit(process, diego_lrp) do |p, l|
                logger.info('updating-lrp', process_guid: p.guid, app_guid: p.app_guid)
                bbs_apps_client.update_app(p, l)
                logger.info('update-lrp', process_guid: p.guid)
              end
            end
          end
        end

        diego_lrps.each_key do |process_guid_to_delete|
          workpool.submit(process_guid_to_delete) do |guid|
            logger.info('deleting-lrp', process_guid: guid)
            bbs_apps_client.stop_app(guid)
            logger.info('delete-lrp', process_guid: guid)
          end
        end

        workpool.drain

        process_workpool_exceptions(@workpool.exceptions)
      rescue CloudController::Errors::ApiError => e
        logger.info('sync-failed', error: e.name, error_message: e.message)
        @bump_freshness = false
        raise BBSFetchError.new(e.message)
      rescue => e
        logger.info('sync-failed', error: e.class.name, error_message: e.message)
        @bump_freshness = false
        raise
      ensure
        workpool.drain
        if @bump_freshness
          bbs_apps_client.bump_freshness
          logger.info('finished-process-sync')
        else
          logger.info('sync-failed')
        end
      end

      private

      attr_reader :config, :workpool

      def process_workpool_exceptions(exceptions)
        invalid_lrps = 0
        exceptions.each do |e|
          error_name = e.is_a?(CloudController::Errors::ApiError) ? e.name : e.class.name
          if error_name == 'RunnerInvalidRequest'
            logger.info('synced-invalid-desired-lrps', error: error_name, error_message: e.message)
            invalid_lrps += 1
          elsif error_name == 'RunnerError' && e.message['the requested resource already exists']
            logger.info('ignore-existing-resource', error: error_name, error_message: e.message)
          elsif error_name == 'RunnerError' && e.message['the requested resource could not be found']
            logger.info('ignore-deleted-resource', error: error_name, error_message: e.message)
          else
            logger.error('error-updating-lrp-state', error: error_name, error_message: e.message, error_backtrace: formatted_backtrace_from_error(e))
            @bump_freshness = false
          end
        end
        @statsd_updater.update_synced_invalid_lrps(invalid_lrps)
      end

      def formatted_backtrace_from_error(error)
        error.backtrace.present? ? error.backtrace.join("\n") + "\n..." : ''
      end

      def batched_processes
        last_id = 0

        loop do
          processes = processes(last_id).all
          yield processes
          return if processes.count < BATCH_SIZE

          last_id = processes.last.id
        end
      end

      def processes(last_id)
        processes = ProcessModel.
                    diego.
                    runnable.
                    where(Sequel.lit("#{ProcessModel.table_name}.id > ?", last_id)).
                    order("#{ProcessModel.table_name}__id".to_sym).
                    eager(:desired_droplet, :space, :service_bindings, { routes: :domain }, { app: :buildpack_lifecycle_data }).
                    limit(BATCH_SIZE)

        if FeatureFlag.enabled?(:diego_docker)
          processes.select_all(ProcessModel.table_name)
        else
          # `select_all` is called by `non_docker_type`
          processes.non_docker_type
        end
      end

      def bbs_apps_client
        CloudController::DependencyLocator.instance.bbs_apps_client
      end

      def logger
        @logger ||= Steno.logger('cc.diego.sync.processes')
      end
    end
  end
end
