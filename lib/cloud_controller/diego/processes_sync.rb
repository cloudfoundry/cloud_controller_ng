require 'utils/workpool'

module VCAP::CloudController
  module Diego
    class ProcessesSync
      BATCH_SIZE = 500

      class Error < StandardError
      end
      class BBSFetchError < Error
      end

      def initialize(config)
        @config   = config
        @workpool = WorkPool.new(50)
      end

      def sync
        diego_lrps = bbs_apps_client.fetch_scheduling_infos.index_by { |d| d.desired_lrp_key.process_guid }

        for_processes do |process|
          process_guid = ProcessGuid.from_process(process)
          diego_lrp    = diego_lrps.delete(process_guid)

          if diego_lrp.nil?
            @workpool.submit(process) do |p|
              recipe_builder = AppRecipeBuilder.new(config: config, process: p)
              bbs_apps_client.desire_app(recipe_builder.build_app_lrp)
            end
          elsif process.updated_at.to_f.to_s != diego_lrp.annotation
            @workpool.submit(process, diego_lrp) do |p, l|
              recipe_builder = AppRecipeBuilder.new(config: config, process: p)
              bbs_apps_client.update_app(process_guid, recipe_builder.build_app_lrp_update(l))
            end
          end
        end

        diego_lrps.keys.each do |process_guid_to_delete|
          @workpool.submit(process_guid_to_delete) do |guid|
            bbs_apps_client.stop_app(guid)
          end
        end

        @workpool.drain

        bbs_apps_client.bump_freshness
      rescue CloudController::Errors::ApiError => e
        logger.info('sync-failed', error: e)
        raise BBSFetchError.new(e.message)
      end

      private

      attr_reader :config

      def for_processes(&block)
        last_id = 0

        loop do
          processes = processes(last_id)
          processes.each(&block)
          return if processes.count < BATCH_SIZE
          last_id = processes.last[0]
        end
      end

      def processes(last_id)
        processes = ProcessModel.
                    diego.
                    runnable.
                    where("#{ProcessModel.table_name}.id > ?", last_id).
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
