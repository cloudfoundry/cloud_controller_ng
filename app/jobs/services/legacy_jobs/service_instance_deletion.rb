module VCAP::CloudController
  module Jobs
    module Services
      ### THIS CLASS IS DEPRECATED
      #
      # We have to leave this job definition for backwards compatibility with any old deployments that still
      # run this job.

      class ServiceInstanceDeletion < VCAP::CloudController::Jobs::CCJob
        attr_accessor :guid

        def initialize(guid)
          @guid = guid
        end

        def perform
          delegate_job = DeleteActionJob.new(ServiceInstance, @guid, ServiceInstanceDelete.new)
          delegate_job.perform
        end

        def job_name_in_configuration
          :model_deletion
        end

        def max_attempts
          1
        end
      end
    end
  end
end
