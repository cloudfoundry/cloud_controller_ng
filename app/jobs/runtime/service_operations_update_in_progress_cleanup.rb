module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceOperationsUpdateInProgressCleanup < VCAP::CloudController::Jobs::CCJob
        BATCH_SIZE = 10

        def perform
          logger.info("Cleaning up service 'update' operations stuck in 'in progress'")
          cleanup_operations(ServiceInstanceOperation, ServiceInstance, :service_instance_id, 'service_instance.update')
        end

        def max_attempts
          1
        end

        private

        def cleanup_operations(operation_model, instance_model, foreign_key, jobs_operation)
          operation_table = operation_model.table_name
          instance_table = instance_model.table_name

          stuck = operation_model.
                  join(instance_table, id: Sequel[operation_table][foreign_key]).
                  join(:jobs, resource_guid: Sequel[instance_table][:guid]).
                  join(:delayed_jobs, guid: Sequel[:jobs][:delayed_job_guid]).
                  where(Sequel[operation_table][:state] => 'in progress').
                  where(Sequel[operation_table][:type] => 'update').
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

            instance_type = instance_model.to_s.split('::').last

            logger.info(
              "#{instance_type} #{instance.guid} update operation is stuck in 'in progress'. " \
              "Setting operation's state to 'failed' and pollable job's state to 'FAILED'.",
              instance_type: instance_type,
              instance_guid: instance.guid,
              operation_id: op_id,
              pollable_job_guid: pollable_guid
            )

            operation.update(state: 'failed',
                             description: "Operation was stuck in 'in progress' state. Set to 'failed' by cleanup job.")
            PollableJobModel.where(guid: pollable_guid).update(state: PollableJobModel::FAILED_STATE)
          end
        end

        def default_maximum_duration_seconds
          Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
        end

        def logger
          @logger ||= Steno.logger('cc.background.service-operations-update-in-progress-cleanup')
        end

        def job_name_in_configuration
          :service_operations_update_in_progress_cleanup
        end
      end
    end
  end
end
