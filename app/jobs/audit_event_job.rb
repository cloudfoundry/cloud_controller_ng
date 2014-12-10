module VCAP::CloudController
  module Jobs
    class AuditEventJob < Struct.new(:job, :event_repository, :event_creation_method, :event_type, :model, :params)
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
    end
  end
end
