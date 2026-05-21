module VCAP::CloudController
  module Jobs
    module Runtime
      class ServiceInstanceOperationsInProgressCleanup < VCAP::CloudController::Jobs::CCJob
        BATCH_SIZE = 10
        def perform
          logger.info("Cleaning up service instance operations stuck 'in progress'")
          cleanup_operations
        end

        def max_attempts
          1
        end

        private

        def cleanup_operations
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
          stuck = ServiceInstanceOperation.
                  join(:service_instances, id: Sequel[:service_instance_operations][:service_instance_id]).
                  join(:jobs, resource_guid: Sequel[:service_instances][:guid]).
                  join(:delayed_jobs, guid: Sequel[:jobs][:delayed_job_guid]).
                  where(Sequel[:service_instance_operations][:state] => 'in progress').
                  where(Sequel[:service_instance_operations][:type] => 'create').
                  where(Sequel.lit("service_instance_operations.created_at > CURRENT_TIMESTAMP - INTERVAL '?' SECOND", default_maximum_duration_seconds.to_i)).
                  where(Sequel[:jobs][:state] => [PollableJobModel::POLLING_STATE, PollableJobModel::FAILED_STATE]).
                  where(Sequel[:jobs][:operation] => 'service_instance.create').
                  exclude(Sequel[:delayed_jobs][:failed_at] => nil).
                  select(
                    Sequel[:jobs][:guid].as(:pollable_guid),
                    Sequel[:service_instance_operations][:id].as(:sio_id),
                    Sequel[:service_instance_operations][:service_instance_id]
                  ).
                  order(Sequel[:service_instance_operations][:created_at]).
                  limit(BATCH_SIZE)

          stuck.each do |row|
            mitigate_orphan(row[:sio_id], row[:service_instance_id], row[:pollable_guid])
          end
        end

        def mitigate_orphan(sio_id, si_id, pj_guid)
          # Mark the stuck create operation as failed, mark its pollable job as failed,
          # and trigger broker-side orphan deprovisioning to clean up any resource the
          # broker may have created.
          ServiceInstanceOperation.db.transaction do
            sio = ServiceInstanceOperation.where(id: sio_id, state: 'in progress').for_update.skip_locked.first
            return unless sio

            instance = ServiceInstance.first(id: si_id)
            return unless instance

            logger.info(
              "ServiceInstance #{instance.guid} create operation is stuck in 'in progress'. " \
              "Setting operation to 'failed', setting pollable job to 'FAILED', and triggering orphan mitigation.",
              service_instance_guid: instance.guid,
              service_instance_operation_guid: sio.guid,
              pollable_job_guid: pj_guid
            )

            sio.update(state: 'failed', description: "Operation was stuck in 'in progress' state. Set to 'failed' by cleanup job; orphan mitigation triggered.")
            PollableJobModel.where(guid: pj_guid).update(state: PollableJobModel::FAILED_STATE)
            orphan_mitigator.cleanup_failed_provision(instance)
          end
        end

        def orphan_mitigator
          @orphan_mitigator ||= VCAP::Services::ServiceBrokers::V2::OrphanMitigator.new
        end

        def default_maximum_duration_seconds
          Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
        end

        def logger
          @logger ||= Steno.logger('cc.background.service-instance-operations-in-progress-cleanup')
        end

        def job_name_in_configuration
          :service_instance_operations_in_progress_cleanup
        end
      end
    end
  end
end
