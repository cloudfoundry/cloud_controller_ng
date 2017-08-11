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
        @workpool = WorkPool.new(50)
        @statsd_updater = statsd_updater
      end

      def sync
        logger.info('run-process-sync')
        bump_freshness = true
        diego_lrps     = bbs_apps_client.fetch_scheduling_infos.index_by { |d| d.desired_lrp_key.process_guid }
        logger.info('fetched-scheduling-infos')

        for_processes do |processes|
          processes.each do |process|
            process_guid = ProcessGuid.from_process(process)
            diego_lrp    = diego_lrps.delete(process_guid)

            if diego_lrp.nil?
              @workpool.submit(process) do |p|
                recipe_builder = AppRecipeBuilder.new(config: config, process: p)
                bbs_apps_client.desire_app(recipe_builder.build_app_lrp)
                logger.info('desire-lrp', process_guid: p.guid)
              end
            elsif process.updated_at.to_f.to_s != diego_lrp.annotation
              @workpool.submit(process, diego_lrp) do |p, l|
                recipe_builder = AppRecipeBuilder.new(config: config, process: p)
                bbs_apps_client.update_app(process_guid, recipe_builder.build_app_lrp_update(l))
                logger.info('update-lrp', process_guid: p.guid)
              end
            end
          end
        end

        diego_lrps.keys.each do |process_guid_to_delete|
          @workpool.submit(process_guid_to_delete) do |guid|
            bbs_apps_client.stop_app(guid)
            logger.info('delete-lrp', process_guid: guid)
          end
        end

        @workpool.drain

        process_exceptions(@workpool.exceptions)
      rescue CloudController::Errors::ApiError => e
        logger.info('sync-failed', error: e.name, error_message: e.message)
        bump_freshness = false
        raise BBSFetchError.new(e.message)
      rescue => e
        logger.info('sync-failed', error: e.class.name, error_message: e.message)
        bump_freshness = false
        raise
      ensure
        if bump_freshness
          bbs_apps_client.bump_freshness
          logger.info('finished-process-sync')
        end
      end

      private

      attr_reader :config

      def process_exceptions(exceptions)
        first_exception = nil
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
            logger.error('error-updating-lrp-state', error: error_name, error_message: e.message)
            first_exception ||= e
          end
        end
        @statsd_updater.update_synced_invalid_lrps(invalid_lrps)
        raise first_exception if first_exception
      end

      def for_processes
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
                    eager(:current_droplet, :space, :service_bindings, { routes: :domain }, { app: :buildpack_lifecycle_data }).
                    limit(BATCH_SIZE)

        processes = processes.buildpack_type unless FeatureFlag.enabled?(:diego_docker)

        processes.select_all(ProcessModel.table_name)
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
