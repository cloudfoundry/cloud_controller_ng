require 'oj'

module VCAP::CloudController
  module Repositories
    class ServiceUsageSnapshotRepository
      BATCH_SIZE = 1000
      CHUNK_LIMIT = 50

      # Populates a snapshot with service instance data, creating chunks of 50 instances per space.
      def populate_snapshot!(snapshot)
        start_time = Time.now

        generator = ChunkGenerator.new(snapshot, CHUNK_LIMIT)

        ServiceUsageSnapshot.db.transaction do
          checkpoint_event = ServiceUsageEvent.order(Sequel.desc(:id)).first

          generator.generate_from_stream(build_service_instance_query)

          snapshot.update(
            checkpoint_event_guid: checkpoint_event&.guid,
            checkpoint_event_created_at: checkpoint_event&.created_at,
            service_instance_count: generator.total_service_instances,
            organization_count: generator.org_guids.size,
            space_count: generator.space_guids.size,
            chunk_count: generator.chunk_count,
            completed_at: Time.now.utc
          )
        end

        snapshot.reload

        duration = Time.now - start_time
        logger.info("Service snapshot #{snapshot.guid} created: " \
                    "#{snapshot.service_instance_count} service instances, #{snapshot.chunk_count} chunks in #{duration.round(2)}s")
        prometheus.update_histogram_metric(:cc_service_usage_snapshot_generation_duration_seconds, duration)

        snapshot
      rescue StandardError => e
        logger.error("Service snapshot generation failed: #{e.message}")
        prometheus.increment_counter_metric(:cc_service_usage_snapshot_generation_failures_total)
        raise
      end

      private

      def build_service_instance_query
        ServiceInstance.
          join(:spaces, id: :service_instances__space_id).
          join(:organizations, id: :spaces__organization_id).
          left_join(:service_plans, id: :service_instances__service_plan_id).
          left_join(:services, id: :service_plans__service_id).
          left_join(:service_brokers, id: :services__service_broker_id).
          order(Sequel.qualify(:spaces, :guid), Sequel.qualify(:service_instances, :id)).
          select(
            Sequel.as(:service_instances__id, :service_instance_id),
            Sequel.as(:service_instances__guid, :guid),
            Sequel.as(:service_instances__name, :name),
            Sequel.as(:service_instances__is_gateway_service, :is_managed),
            Sequel.as(:spaces__guid, :space_guid),
            Sequel.as(:spaces__name, :space_name),
            Sequel.as(:organizations__guid, :organization_guid),
            Sequel.as(:organizations__name, :organization_name),
            Sequel.as(:service_plans__guid, :service_plan_guid),
            Sequel.as(:service_plans__name, :service_plan_name),
            Sequel.as(:services__guid, :service_guid),
            Sequel.as(:services__label, :service_label),
            Sequel.as(:service_brokers__guid, :service_broker_guid),
            Sequel.as(:service_brokers__name, :service_broker_name)
          )
      end

      def prometheus
        @prometheus ||= CloudController::DependencyLocator.instance.prometheus_updater
      end

      def logger
        @logger ||= Steno.logger('cc.service_usage_snapshot_repository')
      end

      class ChunkGenerator
        attr_reader :total_service_instances, :chunk_count, :org_guids, :space_guids

        def initialize(snapshot, chunk_limit)
          @snapshot = snapshot
          @chunk_limit = chunk_limit

          @total_service_instances = 0
          @chunk_count = 0
          @org_guids = Set.new
          @space_guids = Set.new

          @current_space_guid = nil
          @current_space_name = nil
          @current_org_guid = nil
          @current_org_name = nil
          @current_chunk_index = 0
          @current_chunk_instances = []
          @pending_chunks = []
        end

        def generate_from_stream(query)
          query.paged_each(rows_per_fetch: BATCH_SIZE) do |row|
            process_row(row)
          end

          flush_current_chunk if @current_chunk_instances.any?
          flush_pending_chunks
        end

        private

        def process_row(row)
          space_guid = row[:space_guid]
          return if space_guid.nil?

          org_guid = row[:organization_guid]

          if space_guid != @current_space_guid
            flush_current_chunk if @current_chunk_instances.any?
            @current_space_guid = space_guid
            @current_space_name = row[:space_name]
            @current_org_guid = org_guid
            @current_org_name = row[:organization_name]
            @current_chunk_index = 0
            @current_chunk_instances = []
          end

          @org_guids << org_guid
          @space_guids << space_guid
          @total_service_instances += 1

          @current_chunk_instances << {
            service_instance_guid: row[:guid],
            service_instance_name: row[:name],
            service_instance_type: row[:is_managed] ? 'managed' : 'user_provided',
            service_plan_guid: row[:service_plan_guid],
            service_plan_name: row[:service_plan_name],
            service_offering_guid: row[:service_guid],
            service_offering_name: row[:service_label],
            service_broker_guid: row[:service_broker_guid],
            service_broker_name: row[:service_broker_name]
          }

          return unless @current_chunk_instances.size >= @chunk_limit

          flush_current_chunk
          @current_chunk_index += 1
          @current_chunk_instances = []
        end

        def flush_current_chunk
          return if @current_chunk_instances.empty?

          @pending_chunks << {
            service_usage_snapshot_id: @snapshot.id,
            organization_guid: @current_org_guid,
            organization_name: @current_org_name,
            space_guid: @current_space_guid,
            space_name: @current_space_name,
            chunk_index: @current_chunk_index,
            service_instances: Oj.dump(@current_chunk_instances, mode: :compat)
          }
          @chunk_count += 1

          flush_pending_chunks if @pending_chunks.size >= BATCH_SIZE
        end

        def flush_pending_chunks
          return if @pending_chunks.empty?

          ServiceUsageSnapshotChunk.dataset.multi_insert(@pending_chunks)
          @pending_chunks = []
        end
      end
    end
  end
end
