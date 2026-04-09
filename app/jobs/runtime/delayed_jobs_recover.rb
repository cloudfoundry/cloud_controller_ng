module VCAP::CloudController
  module Jobs
    module Runtime
      class DelayedJobsRecover < VCAP::CloudController::Jobs::CCJob
        RECOVERABLE_OPERATIONS = %w[
          service_instance.create
        ].freeze

        def perform
          logger.info('Recover halted delayed jobs')
          recover
        end

        def max_attempts
          1
        end

        private

        def recover
          # find delayed jobs where failed_at is set (permanently failed)
          # and still within the max polling duration (not expired)
          cutoff_time = Time.now - default_maximum_duration_seconds
          dead_delayed_jobs = Delayed::Job.
                              exclude(failed_at: nil).
                              where { created_at > cutoff_time }.
                              order(:created_at).
                              limit(batch_size)

          dead_delayed_jobs.each do |delayed|
            # pollable job state can be POLLING or FAILED depending on whether the failure
            # hook managed to persist before the db connection was lost
            pollable = PollableJobModel.where(delayed_job_guid: delayed.guid).
                       where(state: [PollableJobModel::POLLING_STATE, PollableJobModel::FAILED_STATE]).
                       first
            next unless pollable
            next unless RECOVERABLE_OPERATIONS.include?(pollable.operation)

            # last_operation.state must be 'in progress'. This confirms the broker is still
            # working on the operation and CC is the one that gave up, not the broker
            entity = find_entity(pollable)
            next unless entity
            next unless entity.last_operation&.state == 'in progress'

            reenqueue(pollable, delayed)
          end
        end

        def find_entity(pollable)
          # TODO: resource_type field can be used
          case pollable.operation
          when 'service_instance.create'
            ManagedServiceInstance.first(guid: pollable.resource_guid)
          end
        end

        def reenqueue(pollable, delayed)
          # re-verify atomically that the pollable job still points to this dead delayed_job.
          # if another process already re-enqueued a new job, pollable.delayed_job_guid was
          # updated to the new delayed_job's guid, so where clause returns nil and we skip safely.
          PollableJobModel.db.transaction do
            pjob = PollableJobModel.where(guid: pollable.guid,
                                          delayed_job_guid: delayed.guid,
                                          state: [PollableJobModel::POLLING_STATE, PollableJobModel::FAILED_STATE]).
                   for_update.first
            return unless pjob

            # bring the record into a clean polling state
            pjob.update(cf_api_error: nil, state: PollableJobModel::POLLING_STATE)

            # unwrap the serialized handler and re-enqueue via the reoccurring job
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
