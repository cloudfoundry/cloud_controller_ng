require 'jobs/services/service_instance_deprovision'

module VCAP::CloudController
  module ServiceBrokers
    module V2
      class ServiceInstanceDeprovisioner
        def self.deprovision(client_attrs, service_instance)
          deprovision_job = VCAP::CloudController::Jobs::Services::ServiceInstanceDeprovision.new(
            'service-instance-deprovision',
            client_attrs,
            service_instance.guid,
            service_instance.service_plan.guid
          )

          request_job = VCAP::CloudController::Jobs::RequestJob.new(deprovision_job, ::VCAP::Request.current_id)
          retryable_job = VCAP::CloudController::Jobs::RetryableJob.new(request_job, 0)
          Delayed::Job.enqueue(retryable_job, queue: 'cc-generic', run_at: Delayed::Job.db_time_now)
        end
      end
    end
  end
end
