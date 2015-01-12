require 'jobs/services/service_instance_deprovision'
require 'jobs/services/service_instance_unbind'

module VCAP::Services
  module ServiceBrokers
    module V2
      class OrphanMitigator
        def cleanup_failed_provision(client_attrs, service_instance)
          deprovision_job = VCAP::CloudController::Jobs::Services::ServiceInstanceDeprovision.new(
            'service-instance-deprovision',
            client_attrs,
            service_instance.guid,
            service_instance.service_plan.guid
          )

          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }
          VCAP::CloudController::Jobs::Enqueuer.new(deprovision_job, opts).enqueue
        end

        def cleanup_failed_bind(client_attrs, binding)
          unbind_job = VCAP::CloudController::Jobs::Services::ServiceInstanceUnbind.new(
            'service-instance-unbind',
            client_attrs,
            binding.guid,
            binding.service_instance.guid,
            binding.app.guid
          )

          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }
          VCAP::CloudController::Jobs::Enqueuer.new(unbind_job, opts).enqueue
        end
      end
    end
  end
end
