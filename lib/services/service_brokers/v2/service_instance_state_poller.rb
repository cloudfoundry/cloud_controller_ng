require 'jobs/services/service_instance_state_fetch'

module VCAP::Services
  module ServiceBrokers
    module V2
      class ServiceInstanceStatePoller
        def poll_service_instance_state(client_attrs, service_instance, event_repository_opts=nil, request_attrs={}, poll_interval=nil)
          job = VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
            'service-instance-state-fetch',
            client_attrs,
            service_instance.guid,
            event_repository_opts,
            request_attrs,
            poll_interval,
          )

          default_poll_interval = VCAP::CloudController::Config.config[:broker_client_default_async_poll_interval_seconds]
          poll_interval ||= default_poll_interval
          poll_interval = [[default_poll_interval, poll_interval].max, 24.hours].min
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + poll_interval }
          VCAP::CloudController::Jobs::Enqueuer.new(job, opts).enqueue
        end
      end
    end
  end
end
