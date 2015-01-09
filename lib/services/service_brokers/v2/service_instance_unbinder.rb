require 'jobs/services/service_instance_unbind'

module VCAP::CloudController
  module ServiceBrokers
    module V2
      class ServiceInstanceUnbinder
        def self.delayed_unbind(client_attrs, binding)
          unbind_job = VCAP::CloudController::Jobs::Services::ServiceInstanceUnbind.new(
            'service-instance-unbind',
            client_attrs,
            binding.guid,
            binding.service_instance.guid,
            binding.app.guid
          )

          request_job = VCAP::CloudController::Jobs::RequestJob.new(unbind_job, ::VCAP::Request.current_id)
          retryable_job = VCAP::CloudController::Jobs::RetryableJob.new(request_job, 0)
          Delayed::Job.enqueue(retryable_job, queue: 'cc-generic', run_at: Delayed::Job.db_time_now)
        end
      end
    end
  end
end
