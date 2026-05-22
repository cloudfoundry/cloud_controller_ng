module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceOperationsCreateInProgressCleanup < VCAP::CloudController::Jobs::CCJob
        BATCH_SIZE = 10

        def perform
          logger.info("Cleaning up 'create' type service operations stuck 'in progress'")
          cleanup_operations(ServiceInstanceOperation, ServiceInstance, :service_instance_id, 'service_instance.create',      :cleanup_failed_provision)
          cleanup_operations(ServiceBindingOperation,  ServiceBinding,  :service_binding_id,  'service_bindings.create',      :cleanup_failed_bind)
          cleanup_operations(ServiceKeyOperation,      ServiceKey,      :service_key_id,      'service_keys.create',          :cleanup_failed_key)
        end

        def max_attempts
          1
        end

        private

        def cleanup_operations(operation_model, instance_model, foreign_key, jobs_operation, orphan_mitigator_method)
          # The explanation below uses service_instance_operations as the concrete example;
          # the same logic applies to service_binding_operations and service_key_operations
          # when invoked with their respective arguments.
          #
          # Find stuck service instance 'in progress' operations where the broker is still working
          # but CC's polling job has permanently failed due to a transient error (e.g. brief db connection flip).
          # Join path: service_instance_operations → service_instances → jobs → delayed_jobs.
          #
          # Filters:
          #   - service_instance_operations.state='in progress': the broker has not yet reported a final state
          #     (succeeded or failed) that CC could successfully persist; if CC had received and saved a final
          #     state from the broker, this column would already be 'succeeded' or 'failed' — not 'in progress'
          #   - service_instance_operations.type='create': scope to create operations only
          #   - service_instance_operations.created_at > CURRENT_TIMESTAMP - max_duration: operations beyond the max async polling window
          #     are intentionally excluded — the broker has given up on them too, so they are out of scope for this cleanup
          #   - jobs.state IN (POLLING, FAILED): the pollable job has not reached COMPLETE (a successful job
          #     would already be done and is out of scope); POLLING covers the case where the failure hook
          #     itself couldn't write FAILED due to the DB flip
          #   - jobs.operation='service_instance.create': prevents matching update/delete jobs for the same
          #     service instance that happen to share the same resource_guid
          #   - delayed_jobs.failed_at IS NOT NULL: the delayed job permanently failed (exhausted max_attempts);
          #     jobs still alive or locked have failed_at=NULL and must not be touched
          operation_table = operation_model.table_name
          instance_table = instance_model.table_name

          stuck = operation_model.
                  join(instance_table, id: Sequel[operation_table][foreign_key]).
                  join(:jobs, resource_guid: Sequel[instance_table][:guid]).
                  join(:delayed_jobs, guid: Sequel[:jobs][:delayed_job_guid]).
                  where(Sequel[operation_table][:state] => 'in progress').
                  where(Sequel[operation_table][:type] => 'create').
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
            mitigate_orphan(operation_model, instance_model, orphan_mitigator_method,
                            row[:op_id], row[:resource_id], row[:pollable_guid])
          end
        end

        def mitigate_orphan(operation_model, instance_model, orphan_mitigator_method, op_id, resource_id, pollable_guid)
          # Mark the stuck create operation as failed, mark its pollable job as failed,
          # and trigger broker-side orphan deprovisioning to clean up any resource the
          # broker may have created.
          operation_model.db.transaction do
            operation = operation_model.where(id: op_id, state: 'in progress').for_update.skip_locked.first
            return unless operation

            instance = instance_model.first(id: resource_id)
            return unless instance

            instance_type = instance_model.to_s.split('::').last

            logger.info(
              "#{instance_type} #{instance.guid} create operation is stuck in 'in progress'. " \
              "Setting operation's state to 'failed' and pollable job's state to 'FAILED'.",
              instance_type: instance_type,
              instance_guid: instance.guid,
              operation_id: op_id,
              pollable_job_guid: pollable_guid
            )

            operation.update(state: 'failed',
                             description: "Operation was stuck in 'in progress' state. Set to 'failed' by cleanup job; orphan mitigation triggered.")
            PollableJobModel.where(guid: pollable_guid).update(state: PollableJobModel::FAILED_STATE)
            orphan_mitigator.send(orphan_mitigator_method, instance)
          end
        end

        def orphan_mitigator
          @orphan_mitigator ||= VCAP::Services::ServiceBrokers::V2::OrphanMitigator.new
        end

        def default_maximum_duration_seconds
          Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
        end

        def logger
          @logger ||= Steno.logger('cc.background.service-operations-in-progress-cleanup')
        end

        def job_name_in_configuration
          :service_operations_create_in_progress_cleanup
        end
      end
    end
  end
end
