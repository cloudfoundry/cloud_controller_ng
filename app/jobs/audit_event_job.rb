module VCAP::CloudController
  module Jobs
    class AuditEventJob < VCAP::CloudController::Jobs::CCJob
      attr_accessor :job, :event_repository, :event_creation_method, :event_type, :model, :params

      def initialize(job, event_repository, event_creation_method, event_type, model, params={})
        @job = job
        @event_repository = event_repository
        @event_creation_method = event_creation_method
        @event_type = event_type
        @model = model
        @params = params
      end

      def perform
        job.perform
        event_repository.send(event_creation_method, event_type, model, params)
      end

      def job_name_in_configuration
        :audit_event_job
      end

      def max_attempts
        1
      end

      def reschedule_at(time, attempts)
        job.reschedule_at(time, attempts)
      end
    end
  end
end
