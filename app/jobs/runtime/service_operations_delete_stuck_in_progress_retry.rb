module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceOperationsDeleteStuckInProgressRetry < VCAP::CloudController::Jobs::CCJob
        BATCH_SIZE = 10

        def perform
          logger.info("Retrying stuck service 'delete' operations")
          retry_stuck(ServiceInstanceOperation, ServiceInstance, :service_instance_id, 'service_instance.delete')
        end

        def max_attempts
          1
        end

        private

        def retry_stuck(operation_model, instance_model, foreign_key, jobs_operation)
          # Find stuck service instance 'delete' operations where the broker may still be working
          # but CC's polling job has permanently failed due to a transient error (e.g. brief db connection flip).
          #
          # Unlike create/update we do not mark the operation failed: for a delete we re-enqueue the original
          # polling job so the deprovision is driven to completion. The original delayed_job's serialized handler
          # is reused, preserving @start_time so the ReoccurringJob max-duration expiry (which marks the operation
          # failed via handle_timeout) still fires against the original polling window.
          operation_table = operation_model.table_name
          instance_table = instance_model.table_name

          stuck = operation_model.
                  join(instance_table, id: Sequel[operation_table][foreign_key]).
                  join(:jobs, resource_guid: Sequel[instance_table][:guid]).
                  join(:delayed_jobs, guid: Sequel[:jobs][:delayed_job_guid]).
                  where(Sequel[operation_table][:state] => 'in progress').
                  where(Sequel[operation_table][:type] => 'delete').
                  where(Sequel.lit("#{operation_table}.created_at > CURRENT_TIMESTAMP - INTERVAL '?' SECOND", default_maximum_duration_seconds.to_i)).
                  where(Sequel[:jobs][:state] => [PollableJobModel::POLLING_STATE, PollableJobModel::FAILED_STATE]).
                  where(Sequel[:jobs][:operation] => jobs_operation).
                  exclude(Sequel[:delayed_jobs][:failed_at] => nil).
                  select(
                    Sequel[:jobs][:guid].as(:pollable_guid),
                    Sequel[operation_table][:id].as(:op_id),
                    Sequel[operation_table][foreign_key].as(:resource_id)
                  ).
                  order(Sequel[operation_table][:created_at]).
                  limit(BATCH_SIZE)

          stuck.each do |row|
            resolve_stuck(operation_model, instance_model, row[:op_id], row[:resource_id], row[:pollable_guid])
          end
        end

        def resolve_stuck(operation_model, instance_model, op_id, resource_id, pollable_guid)
          operation_model.db.transaction do
            operation = operation_model.where(id: op_id, state: 'in progress').for_update.skip_locked.first
            return unless operation

            instance = instance_model.first(id: resource_id)
            return unless instance

            pollable = PollableJobModel.first(guid: pollable_guid)
            return unless pollable

            handler = deserialize_handler(pollable)
            return unless handler

            instance_type = instance_model.to_s.split('::').last

            logger.info(
              "#{instance_type} #{instance.guid} delete operation is stuck in 'in progress'. Re-enqueuing the polling job.",
              instance_type: instance_type,
              instance_guid: instance.guid,
              operation_id: op_id,
              pollable_job_guid: pollable_guid
            )

            pollable.update(state: PollableJobModel::POLLING_STATE, cf_api_error: nil)
            Jobs::GenericEnqueuer.shared.enqueue_pollable(handler, existing_guid: pollable.guid, preserve_priority: true)
          end
        end

        # Reuse the original delete polling job by deserializing the failed delayed_job's handler and unwrapping
        # the wrapper chain (LoggingContextJob → TimeoutJob → PollableJobWrapper → DeleteServiceInstanceJob).
        # This preserves the original @user_audit_info, @start_time and the recursive-vs-plain delete variant.
        def deserialize_handler(pollable)
          delayed_job = Delayed::Job[guid: pollable.delayed_job_guid]
          return unless delayed_job

          Jobs::Enqueuer.unwrap_job(delayed_job.payload_object)
        rescue StandardError => e
          logger.error("Could not deserialize delayed job '#{pollable.delayed_job_guid}' for pollable '#{pollable.guid}': #{e.class}: #{e.message}")
          nil
        end

        def default_maximum_duration_seconds
          Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
        end

        def logger
          @logger ||= Steno.logger('cc.background.service-operations-delete-stuck-in-progress-retry')
        end

        def job_name_in_configuration
          :service_operations_delete_stuck_in_progress_retry
        end
      end
    end
  end
end
