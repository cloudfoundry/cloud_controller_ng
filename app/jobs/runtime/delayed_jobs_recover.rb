module VCAP::CloudController
  module Jobs
    module Runtime
      class DelayedJobsRecover < VCAP::CloudController::Jobs::CCJob
        def perform
          logger.info('Recover halted delayed jobs')
          recover
        end

        def max_attempts
          1
        end

        private

        def recover
          # Find stuck service instance create operations where the broker is still working
          # but CC's polling job has permanently failed due to a transient error (e.g. brief db connection flip).
          # Join path: service_instance_operations → service_instances → jobs → delayed_jobs.
          #
          # Filters:
          #   - service_instance_operations.state='in progress': the broker has not yet reported a final state
          #     (succeeded or failed) that CC could successfully persist; if CC had received and saved a final
          #     state from the broker, this column would already be 'succeeded' or 'failed' — not 'in progress'
          #   - service_instance_operations.type='create': scope to create operations only
          #   - service_instance_operations.created_at > cutoff: operations beyond the max async polling window
          #     are intentionally excluded — the broker has given up on them too, so re-enqueuing is pointless
          #   - jobs.state IN (POLLING, FAILED): the pollable job has not reached a terminal success state;
          #     POLLING covers the case where the failure hook itself couldn't write FAILED due to the DB flip
          #   - jobs.operation='service_instance.create': prevents matching update/delete jobs for the same
          #     service instance that happen to share the same resource_guid
          #   - delayed_jobs.failed_at IS NOT NULL: the delayed job permanently failed (exhausted max_attempts);
          #     jobs still alive or locked have failed_at=NULL and must not be touched
          cutoff_time = Time.now - default_maximum_duration_seconds
          stuck = ServiceInstanceOperation.
                  join(:service_instances, id: Sequel[:service_instance_operations][:service_instance_id]).
                  join(:jobs, resource_guid: Sequel[:service_instances][:guid]).
                  join(:delayed_jobs, guid: Sequel[:jobs][:delayed_job_guid]).
                  where(Sequel[:service_instance_operations][:state] => 'in progress').
                  where(Sequel[:service_instance_operations][:type] => 'create').
                  where { Sequel[:service_instance_operations][:created_at] > cutoff_time }.
                  where(Sequel[:jobs][:state] => [PollableJobModel::POLLING_STATE, PollableJobModel::FAILED_STATE]).
                  where(Sequel[:jobs][:operation] => 'service_instance.create').
                  exclude(Sequel[:delayed_jobs][:failed_at] => nil).
                  select(Sequel[:jobs][:guid].as(:pollable_guid), Sequel[:delayed_jobs][:guid].as(:dj_guid)).
                  order(Sequel[:service_instance_operations][:created_at]).
                  limit(batch_size)

          stuck.each do |row|
            delayed = Delayed::Job.first(guid: row[:dj_guid])
            next unless delayed

            reenqueue(row[:pollable_guid], delayed)
          end
        end

        def reenqueue(pollable_guid, delayed)
          # re-verify atomically that the pollable job still points to this dead delayed_job.
          # if another process already re-enqueued a new job, pollable.delayed_job_guid was
          # updated to the new delayed_job's guid, so where clause returns nil and we skip safely.
          PollableJobModel.db.transaction do
            pjob = PollableJobModel.where(guid: pollable_guid,
                                          delayed_job_guid: delayed.guid).
                   for_update.first
            return unless pjob

            # bring the pollable job into the clean polling state
            pjob.update(cf_api_error: nil, state: PollableJobModel::POLLING_STATE)

            # unwrap the serialized handler and re-enqueue via the reoccurring job's enqueue_next_job method
            inner_job = Jobs::Enqueuer.unwrap_job(delayed.payload_object)
            inner_job.send(:enqueue_next_job, pjob)
          end
        end

        def default_maximum_duration_seconds
          Config.config.get(:broker_client_max_async_poll_duration_minutes).minutes
        end

        def logger
          @logger ||= Steno.logger('cc.background')
        end

        def batch_size
          10
        end
      end
    end
  end
end
