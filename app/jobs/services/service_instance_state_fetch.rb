module VCAP::CloudController
  module Jobs
    module Services
      class ServiceInstanceStateFetch < VCAP::CloudController::Jobs::CCJob
        attr_accessor :name, :client_attrs, :service_instance_guid, :service_plan_guid

        def initialize(name, client_attrs, service_instance_guid, service_plan_guid)
          @name = name
          @client_attrs = client_attrs
          @service_instance_guid = service_instance_guid
          @service_plan_guid = service_plan_guid
        end

        def perform
          client = VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
          service_plan = ServicePlan.first(guid: service_plan_guid)
          service_instance = ManagedServiceInstance.first(guid: service_instance_guid, service_plan: service_plan)
          client.fetch_service_instance_state(service_instance)

          service_instance.save

          if service_instance.state != 'available'
            retry_job
          end
        rescue HttpRequestError, Sequel::Error
          retry_job
        end

        def job_name_in_configuration
          :service_instance_state_fetch
        end

        def max_attempts
          1
        end

        private

        def retry_job
          poll_interval = 1.minute
          opts = { queue: 'cc-generic', run_at: Delayed::Job.db_time_now + poll_interval }
          VCAP::CloudController::Jobs::Enqueuer.new(self, opts).enqueue
        end
      end
    end
  end
end
