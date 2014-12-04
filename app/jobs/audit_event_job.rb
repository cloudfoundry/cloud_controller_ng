module VCAP::CloudController
  module Jobs
    class AuditEventJob < Struct.new(:job, :event_repository, :event_creation_method, :event_type, :model, :params)
      def perform
        job.perform
        event_repository.send(event_creation_method, event_type, model, params)
      end
    end
  end
end
