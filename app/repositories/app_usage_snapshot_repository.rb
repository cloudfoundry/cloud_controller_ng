require 'oj'

module VCAP::CloudController
  module Repositories
    class AppUsageSnapshotRepository
      BATCH_SIZE = 1000
      CHUNK_LIMIT = 50

      # Populates a snapshot with process data, creating chunks of 50 processes per space.
      def populate_snapshot!(snapshot)
        start_time = Time.now

        generator = ChunkGenerator.new(snapshot, CHUNK_LIMIT)

        AppUsageSnapshot.db.transaction do
          checkpoint_event = AppUsageEvent.order(Sequel.desc(:id)).first

          generator.generate_from_stream(build_process_query)

          snapshot.update(
            checkpoint_event_guid: checkpoint_event&.guid,
            checkpoint_event_created_at: checkpoint_event&.created_at,
            instance_count: generator.total_instances,
            organization_count: generator.org_guids.size,
            space_count: generator.space_guids.size,
            app_count: generator.app_guids.size,
            chunk_count: generator.chunk_count,
            completed_at: Time.now.utc
          )
        end

        snapshot.reload

        duration = Time.now - start_time
        logger.info("Snapshot #{snapshot.guid} created: #{snapshot.instance_count} instances, " \
                    "#{snapshot.app_count} apps, #{snapshot.chunk_count} chunks in #{duration.round(2)}s")
        prometheus.update_histogram_metric(:cc_app_usage_snapshot_generation_duration_seconds, duration)

        snapshot
      rescue StandardError => e
        logger.error("Snapshot generation failed: #{e.message}")
        prometheus.increment_counter_metric(:cc_app_usage_snapshot_generation_failures_total)
        raise
      end

      private

      def build_process_query
        ProcessModel.
          join(AppModel.table_name, { guid: :app_guid }, table_alias: :parent_app).
          join(Space.table_name, guid: :space_guid).
          join(Organization.table_name, id: :organization_id).
          left_join(DropletModel.table_name, { guid: :parent_app__droplet_guid }, table_alias: :desired_droplet).
          where("#{ProcessModel.table_name}__state": ProcessModel::STARTED).
          exclude("#{ProcessModel.table_name}__type": %w[TASK build]).
          order(Sequel.qualify(Space.table_name, :guid), Sequel.qualify(ProcessModel.table_name, :id)).
          select(
            Sequel.as(:"#{ProcessModel.table_name}__id", :process_id),
            Sequel.as(:"#{ProcessModel.table_name}__guid", :process_guid),
            Sequel.as(:"#{ProcessModel.table_name}__type", :process_type),
            Sequel.as(:"#{ProcessModel.table_name}__instances", :instances),
            Sequel.as(:"#{ProcessModel.table_name}__memory", :memory),
            Sequel.as(:parent_app__guid, :app_guid),
            Sequel.as(:parent_app__name, :app_name),
            Sequel.as(:"#{Space.table_name}__guid", :space_guid),
            Sequel.as(:"#{Space.table_name}__name", :space_name),
            Sequel.as(:"#{Organization.table_name}__guid", :organization_guid),
            Sequel.as(:"#{Organization.table_name}__name", :organization_name),
            Sequel.as(:desired_droplet__buildpack_receipt_buildpack_guid, :buildpack_guid),
            Sequel.as(:desired_droplet__buildpack_receipt_buildpack, :buildpack_name)
          )
      end

      def prometheus
        @prometheus ||= CloudController::DependencyLocator.instance.prometheus_updater
      end

      def logger
        @logger ||= Steno.logger('cc.app_usage_snapshot_repository')
      end

      class ChunkGenerator
        attr_reader :total_instances, :chunk_count, :org_guids, :space_guids, :app_guids

        def initialize(snapshot, chunk_limit)
          @snapshot = snapshot
          @chunk_limit = chunk_limit

          @total_instances = 0
          @chunk_count = 0
          @org_guids = Set.new
          @space_guids = Set.new
          @app_guids = Set.new

          @current_space_guid = nil
          @current_space_name = nil
          @current_org_guid = nil
          @current_org_name = nil
          @current_chunk_index = 0
          @current_chunk_processes = []
          @pending_chunks = []
        end

        def generate_from_stream(query)
          query.paged_each(rows_per_fetch: BATCH_SIZE) do |row|
            process_row(row)
          end

          flush_current_chunk if @current_chunk_processes.any?
          flush_pending_chunks
        end

        private

        def process_row(row)
          space_guid = row[:space_guid]
          return if space_guid.nil?

          org_guid = row[:organization_guid]

          if space_guid != @current_space_guid
            flush_current_chunk if @current_chunk_processes.any?
            @current_space_guid = space_guid
            @current_space_name = row[:space_name]
            @current_org_guid = org_guid
            @current_org_name = row[:organization_name]
            @current_chunk_index = 0
            @current_chunk_processes = []
          end

          @org_guids << org_guid
          @space_guids << space_guid
          @app_guids << row[:app_guid]
          instance_count = row[:instances] || 0
          @total_instances += instance_count

          @current_chunk_processes << {
            app_guid: row[:app_guid],
            app_name: row[:app_name],
            process_guid: row[:process_guid],
            process_type: row[:process_type],
            instance_count: row[:instances],
            memory_in_mb_per_instance: row[:memory],
            buildpack_guid: row[:buildpack_guid],
            buildpack_name: row[:buildpack_name]
          }

          return unless @current_chunk_processes.size >= @chunk_limit

          flush_current_chunk
          @current_chunk_index += 1
          @current_chunk_processes = []
        end

        def flush_current_chunk
          return if @current_chunk_processes.empty?

          @pending_chunks << {
            app_usage_snapshot_id: @snapshot.id,
            organization_guid: @current_org_guid,
            organization_name: @current_org_name,
            space_guid: @current_space_guid,
            space_name: @current_space_name,
            chunk_index: @current_chunk_index,
            processes: Oj.dump(@current_chunk_processes, mode: :compat)
          }
          @chunk_count += 1

          flush_pending_chunks if @pending_chunks.size >= BATCH_SIZE
        end

        def flush_pending_chunks
          return if @pending_chunks.empty?

          AppUsageSnapshotChunk.dataset.multi_insert(@pending_chunks)
          @pending_chunks = []
        end
      end
    end
  end
end
