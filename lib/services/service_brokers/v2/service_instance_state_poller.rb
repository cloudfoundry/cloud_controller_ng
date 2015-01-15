require 'jobs/services/service_instance_state_fetch'

module VCAP::Services
  module ServiceBrokers
    module V2
      class ServiceInstanceStatePoller
        def poll_service_instance_state(client_attrs, service_instance)
          job = VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
            'service-instance-state-fetch',
            client_attrs,
            service_instance.guid,
            service_instance.service_plan.guid
          )

          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }
          VCAP::CloudController::Jobs::Enqueuer.new(job, opts).enqueue
        end
      end
    end
  end
end
