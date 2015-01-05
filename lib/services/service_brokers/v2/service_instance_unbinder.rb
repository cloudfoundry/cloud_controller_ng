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
          Delayed::Job.enqueue(unbind_job, queue: 'cc-generic', run_at: Delayed::Job.db_time_now)
          unbind_job
        end
      end
    end
  end
end
